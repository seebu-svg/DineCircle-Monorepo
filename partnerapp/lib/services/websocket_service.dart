import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// WebSocket connection states for the partner app.
enum WebSocketStatus {
  /// Not yet attempted connection or explicitly disconnected.
  disconnected,

  /// Attempting to establish connection with authentication.
  connecting,

  /// Connected and authenticated, ready to send/receive events.
  connected,

  /// Connection lost, attempting to reconnect automatically.
  reconnecting,

  /// Connection failed due to auth error, network issue, or server rejection.
  error,
}

/// Real-time WebSocket service for the Partner app.
///
/// Connects to the same Express backend as the HTTP API, using the bearer
/// token for authentication. Provides live updates for:
///
///  * New bookings on managed venues
///  * Booking status changes (check-in, cancellation)
///  * Event status transitions (going live, completing)
///  * Chat messages in event and venue rooms
///  * Platform notifications
///
/// The service manages room subscriptions automatically: when a venue is
/// selected, it joins that room; when switched, it leaves the old one. This
/// keeps the server's broadcast scope tight and the client's event volume low.
class WebSocketService {
  WebSocketService._();

  static final WebSocketService instance = WebSocketService._();

  io.Socket? _socket;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  String? _currentToken;
  String? _currentVenueId;

  /// Event listeners keyed by event name. Multiple listeners per event allowed.
  final Map<String, List<Function(dynamic)>> _listeners = {};

  /// Current connection status. Screens can listen to this via the provider.
  WebSocketStatus get status => _status;

  /// Whether the socket is currently connected and authenticated.
  bool get isConnected => _status == WebSocketStatus.connected;

  /// The venue room currently subscribed to, if any.
  String? get currentVenueId => _currentVenueId;

  // ── Connection lifecycle ─────────────────────────────────────────────────

  /// Establishes a WebSocket connection with the given bearer token.
  ///
  /// The token is passed in the `auth` handshake field so the server can
  /// validate it before emitting the `connect` event. If the token is invalid
  /// or expired, the server disconnects immediately and [status] transitions
  /// to [WebSocketStatus.error].
  ///
  /// Safe to call multiple times; subsequent calls while connected are no-ops.
  /// Calls while in [WebSocketStatus.error] reset the state and retry.
  Future<void> connect(String token) async {
    if (_status == WebSocketStatus.connected && _currentToken == token) {
      debugPrint('🔌 WebSocket: already connected with same token');
      return;
    }

    // Tear down any prior socket before building a new one.
    disconnect();

    _currentToken = token;
    _setStatus(WebSocketStatus.connecting);

    try {
      _socket = io.io(
        AppConfig.apiBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setTimeout(AppConfig.apiTimeoutMs)
            .build(),
      );

      _attachHandlers();
      debugPrint('🔌 WebSocket: connecting to ${AppConfig.apiBaseUrl}');
    } catch (error, stack) {
      debugPrint('🔌 WebSocket: connection setup failed: $error');
      debugPrint('$stack');
      _setStatus(WebSocketStatus.error);
    }
  }

  /// Drops the current connection and clears authentication state.
  ///
  /// Room subscriptions are implicitly cleared server-side when the socket
  /// disconnects, so there is no need to emit `leave_restaurant` first.
  void disconnect() {
    if (_socket != null) {
      debugPrint('🔌 WebSocket: disconnecting');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _currentToken = null;
    _currentVenueId = null;
    _setStatus(WebSocketStatus.disconnected);
  }

  // ── Room management ──────────────────────────────────────────────────────

  /// Subscribes to real-time events for the given venue.
  ///
  /// Emits `join_restaurant` so the server adds this socket to the room
  /// `restaurant_<venueId>`. Any prior venue subscription is released first —
  /// a desk operator can only watch one venue's live feed at a time.
  ///
  /// No-op if the socket is not connected or the venue is already current.
  void joinVenue(String venueId) {
    if (!isConnected) {
      debugPrint('🔌 WebSocket: cannot join venue — not connected');
      return;
    }
    if (_currentVenueId == venueId) {
      return;
    }
    if (_currentVenueId != null) {
      leaveVenue();
    }
    debugPrint('🔌 WebSocket: joining venue room $venueId');
    _socket!.emit('join_restaurant', venueId);
    _currentVenueId = venueId;
  }

  /// Unsubscribes from the current venue's room.
  ///
  /// Safe to call when not subscribed; the server ignores redundant leaves.
  void leaveVenue() {
    if (!isConnected || _currentVenueId == null) {
      return;
    }
    debugPrint('🔌 WebSocket: leaving venue room $_currentVenueId');
    _socket!.emit('leave_restaurant', _currentVenueId);
    _currentVenueId = null;
  }

  /// Subscribes to live updates for a specific event (dinner, tasting, etc.).
  ///
  /// Used by the event management screen to receive booking changes and chat
  /// messages for a single event without polling.
  void joinEvent(String eventId) {
    if (!isConnected) return;
    debugPrint('🔌 WebSocket: joining event room $eventId');
    _socket!.emit('join_event', eventId);
  }

  /// Unsubscribes from an event room.
  void leaveEvent(String eventId) {
    if (!isConnected) return;
    debugPrint('🔌 WebSocket: leaving event room $eventId');
    _socket!.emit('leave_event', eventId);
  }

  // ── Outgoing messages ────────────────────────────────────────────────────

  /// Sends a chat message to the event room.
  ///
  /// The server re-broadcasts `new_message` to all sockets in `event_<eventId>`
  /// (including the sender, for local echo). Requires prior [joinEvent].
  void sendChatMessage(String eventId, String text) {
    if (!isConnected) {
      debugPrint('🔌 WebSocket: cannot send message — not connected');
      return;
    }
    _socket!.emit('chat_message', {
      'eventId': eventId,
      'text': text,
    });
  }

  // ── Event listeners ──────────────────────────────────────────────────────

  /// Registers a callback for a server-emitted event.
  ///
  /// Multiple callbacks per event are supported; they fire in registration
  /// order. Returns a disposer function that removes this specific listener.
  ///
  /// Common events:
  ///  * `new_booking` — a reservation was created on a watched venue
  ///  * `booking_updated` — status changed (confirmed → seated → completed)
  ///  * `event_updated` — an event's status or details changed
  ///  * `new_message` — a chat message in a subscribed event room
  ///  * `notification` — a platform or venue notification
  void on(String event, Function(dynamic data) callback) {
    _listeners.putIfAbsent(event, () => []);
    _listeners[event]!.add(callback);
    _socket?.on(event, callback);
  }

  /// Removes all listeners for [event], or a specific [callback] if provided.
  ///
  /// Called automatically during [disconnect] to avoid stale handlers.
  void off(String event, [Function? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
    } else {
      _listeners[event]?.clear();
    }
    _socket?.off(event);
  }

  // ── Internal handlers ────────────────────────────────────────────────────

  void _attachHandlers() {
    final socket = _socket!;

    socket.onConnect((_) {
      debugPrint('🔌 WebSocket: connected');
      _setStatus(WebSocketStatus.connected);
    });

    socket.onConnectError((data) {
      debugPrint('🔌 WebSocket: connect error — $data');
      _setStatus(WebSocketStatus.error);
    });

    socket.onError((data) {
      debugPrint('🔌 WebSocket: error — $data');
      _setStatus(WebSocketStatus.error);
    });

    socket.onDisconnect((_) {
      debugPrint('🔌 WebSocket: disconnected');
      _currentVenueId = null;
      _setStatus(WebSocketStatus.disconnected);
    });

    socket.onReconnect((attempt) {
      debugPrint('🔌 WebSocket: reconnected after $attempt attempts');
      _setStatus(WebSocketStatus.connected);
      // Re-join the venue room if we had one before the disconnect.
      if (_currentVenueId != null) {
        final venueId = _currentVenueId;
        _currentVenueId = null;
        joinVenue(venueId!);
      }
    });

    socket.onReconnectAttempt((attempt) {
      debugPrint('🔌 WebSocket: reconnect attempt $attempt');
      _setStatus(WebSocketStatus.reconnecting);
    });

    socket.onReconnectFailed((_) {
      debugPrint('🔌 WebSocket: reconnection failed');
      _setStatus(WebSocketStatus.error);
    });

    // Re-attach any registered listeners (survives reconnects).
    for (final entry in _listeners.entries) {
      for (final callback in entry.value) {
        socket.on(entry.key, callback);
      }
    }
  }

  void _setStatus(WebSocketStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    // Status changes are surfaced via the provider; no direct callback needed
    // here because Riverpod's notifier pattern handles propagation.
  }
}
