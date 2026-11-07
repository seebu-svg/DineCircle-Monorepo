import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/websocket_service.dart';

/// Example widget showing WebSocket connection status and real-time updates.
///
/// Demonstrates:
///  * Connection status indicator
///  * Venue room subscription
///  * Event listeners for new bookings
///  * Automatic cleanup on dispose
///
/// Use this as a reference when building screens that need real-time updates.
class WebSocketStatusWidget extends ConsumerStatefulWidget {
  const WebSocketStatusWidget({
    super.key,
    required this.venueId,
    this.showDetails = false,
  });

  /// The venue to subscribe to. Pass null to show status only.
  final String? venueId;

  /// Whether to show detailed event log.
  final bool showDetails;

  @override
  ConsumerState<WebSocketStatusWidget> createState() =>
      _WebSocketStatusWidgetState();
}

class _WebSocketStatusWidgetState extends ConsumerState<WebSocketStatusWidget> {
  final _eventLog = <String>[];

  @override
  void initState() {
    super.initState();
    
    // Subscribe to venue room after first frame
    if (widget.venueId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinVenue();
      });
    }
  }

  @override
  void dispose() {
    // Leave venue room and clean up listeners
    if (widget.venueId != null) {
      _leaveVenue();
    }
    super.dispose();
  }

  void _joinVenue() {
    final socket = ref.read(webSocketServiceProvider);
    socket.joinVenue(widget.venueId!);
    
    // Register event listeners
    socket.on('new_booking', _onNewBooking);
    socket.on('booking_updated', _onBookingUpdated);
    socket.on('event_updated', _onEventUpdated);
    socket.on('notification', _onNotification);
    
    _log('📡 Joined venue room: ${widget.venueId}');
  }

  void _leaveVenue() {
    final socket = ref.read(webSocketServiceProvider);
    socket.leaveVenue();
    
    // Remove listeners
    socket.off('new_booking');
    socket.off('booking_updated');
    socket.off('event_updated');
    socket.off('notification');
    
    _log('📡 Left venue room');
  }

  void _onNewBooking(dynamic data) {
    _log('🎉 New booking: $data');
    
    // Show snackbar notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New booking received!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    // Invalidate bookings provider to refresh list
    // ref.invalidate(bookingsProvider);
  }

  void _onBookingUpdated(dynamic data) {
    _log('🔄 Booking updated: $data');
  }

  void _onEventUpdated(dynamic data) {
    _log('📅 Event updated: $data');
  }

  void _onNotification(dynamic data) {
    _log('🔔 Notification: $data');
  }

  void _log(String message) {
    if (!widget.showDetails) return;
    
    setState(() {
      final timestamp = TimeOfDay.now().format(context);
      _eventLog.insert(0, '[$timestamp] $message');
      
      // Keep only last 50 entries
      if (_eventLog.length > 50) {
        _eventLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(webSocketStatusProvider);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.venueId != null) ...[
                const SizedBox(width: 16),
                Icon(
                  status == WebSocketStatus.connected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: status == WebSocketStatus.connected
                      ? Colors.green
                      : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Room subscribed',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          
          // Event log (if enabled)
          if (widget.showDetails && _eventLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Event Log:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _eventLog.length,
                itemBuilder: (context, index) {
                  return Text(
                    _eventLog[index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return Icons.wifi;
      case WebSocketStatus.connecting:
      case WebSocketStatus.reconnecting:
        return Icons.wifi_find;
      case WebSocketStatus.error:
        return Icons.wifi_off;
      case WebSocketStatus.disconnected:
        return Icons.signal_wifi_off;
    }
  }

  Color _getStatusColor(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return Colors.green;
      case WebSocketStatus.connecting:
      case WebSocketStatus.reconnecting:
        return Colors.orange;
      case WebSocketStatus.error:
        return Colors.red;
      case WebSocketStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusText(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.connected:
        return 'Connected';
      case WebSocketStatus.connecting:
        return 'Connecting...';
      case WebSocketStatus.reconnecting:
        return 'Reconnecting...';
      case WebSocketStatus.error:
        return 'Connection Error';
      case WebSocketStatus.disconnected:
        return 'Disconnected';
    }
  }
}

/// Simple connection status indicator (icon only).
///
/// Use in app bars or status bars where space is limited.
class WebSocketStatusIcon extends ConsumerWidget {
  const WebSocketStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(webSocketStatusProvider);
    
    Color color;
    IconData icon;
    
    switch (status) {
      case WebSocketStatus.connected:
        color = Colors.green;
        icon = Icons.wifi;
      case WebSocketStatus.connecting:
      case WebSocketStatus.reconnecting:
        color = Colors.orange;
        icon = Icons.wifi_find;
      case WebSocketStatus.error:
        color = Colors.red;
        icon = Icons.wifi_off;
      case WebSocketStatus.disconnected:
        color = Colors.grey;
        icon = Icons.signal_wifi_off;
    }
    
    return Tooltip(
      message: status.name.toUpperCase(),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
