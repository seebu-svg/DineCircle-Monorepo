# WebSocket Integration Guide

The DineCircle Partner app includes real-time WebSocket support for live updates without polling.

## Overview

The WebSocket service connects to the same Express backend as the HTTP API, providing instant notifications for:

- **New bookings** — guest makes a reservation
- **Booking updates** — status changes (confirmed → seated → completed)
- **Event changes** — event status transitions
- **Chat messages** — real-time communication in event rooms
- **Notifications** — platform and venue alerts

## Architecture

```
┌─────────────────┐
│  Partner App    │
│  (Flutter)      │
└────────┬────────┘
         │
         │ WebSocket (Socket.io)
         │
┌────────▼────────┐
│  Backend API    │
│  (Express.js)   │
│  + Socket.io    │
└────────┬────────┘
         │
         │ Broadcasts to room
         │
┌────────▼────────┐
│  Other Clients  │
│  (Customer App) │
└─────────────────┘
```

## Connection Lifecycle

### Automatic Connection

The WebSocket connects **automatically** when the user signs in:

```dart
// In app_providers.dart
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService.instance;
  
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    if (!wasSignedIn && isSignedIn && token != null) {
      service.connect(token);  // Auto-connect on sign-in
    } else if (wasSignedIn && !isSignedIn) {
      service.disconnect();    // Auto-disconnect on sign-out
    }
  });
  
  return service;
});
```

### Manual Connection

You can also connect manually if needed:

```dart
final socket = ref.read(webSocketServiceProvider);
await socket.connect(bearerToken);
```

## Room Subscriptions

### Venue Rooms

Subscribe to all events for a specific venue:

```dart
final socket = ref.read(webSocketServiceProvider);

// Join venue room
socket.joinVenue('venue-uuid-here');

// Leave venue room
socket.leaveVenue();
```

**Events received**:
- `new_booking` — new reservation on this venue
- `booking_updated` — booking status changed
- `notification` — venue-specific notification

### Event Rooms

Subscribe to a specific event (dinner, tasting, etc.):

```dart
// Join event room
socket.joinEvent('event-uuid-here');

// Leave event room
socket.leaveEvent('event-uuid-here');
```

**Events received**:
- `booking_updated` — booking changes for this event
- `event_updated` — event details changed
- `new_message` — chat message in this event

## Listening to Events

### Register Event Listeners

```dart
final socket = ref.read(webSocketServiceProvider);

// Listen for new bookings
socket.on('new_booking', (data) {
  print('New booking: $data');
  // Refresh bookings list
  ref.invalidate(bookingsProvider);
});

// Listen for booking updates
socket.on('booking_updated', (data) {
  print('Booking updated: $data');
  // Update local state
});

// Listen for chat messages
socket.on('new_message', (data) {
  print('Chat message: $data');
  // Add to message list
});
```

### Remove Listeners

```dart
// Remove specific listener
socket.off('new_booking', myCallback);

// Remove all listeners for an event
socket.off('new_booking');
```

## Sending Messages

### Chat Messages

Send a message to an event room (must be subscribed first):

```dart
final socket = ref.read(webSocketServiceProvider);

// Join the event room first
socket.joinEvent('event-uuid');

// Send message
socket.sendChatMessage('event-uuid', 'Hello from the partner app!');
```

## Connection Status

### Check Status

```dart
final socket = ref.read(webSocketServiceProvider);

if (socket.isConnected) {
  // Socket is connected and authenticated
}

// Or use the provider
final status = ref.watch(webSocketStatusProvider);
switch (status) {
  case WebSocketStatus.connected:
    // Show green indicator
  case WebSocketStatus.connecting:
  case WebSocketStatus.reconnecting:
    // Show yellow indicator
  case WebSocketStatus.error:
  case WebSocketStatus.disconnected:
    // Show red indicator
}
```

### Status Values

- `disconnected` — Not connected
- `connecting` — Attempting to connect
- `connected` — Connected and authenticated
- `reconnecting` — Lost connection, attempting to reconnect
- `error` — Connection failed (auth error, network issue, etc.)

## Example: Bookings Screen

```dart
class BookingsScreen extends ConsumerStatefulWidget {
  final String venueId;
  
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  @override
  void initState() {
    super.initState();
    
    // Subscribe to venue updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ref.read(webSocketServiceProvider);
      socket.joinVenue(widget.venueId);
      
      // Listen for new bookings
      socket.on('new_booking', _onNewBooking);
      socket.on('booking_updated', _onBookingUpdated);
    });
  }
  
  @override
  void dispose() {
    // Unsubscribe when leaving
    final socket = ref.read(webSocketServiceProvider);
    socket.leaveVenue();
    socket.off('new_booking');
    socket.off('booking_updated');
    
    super.dispose();
  }
  
  void _onNewBooking(dynamic data) {
    // Refresh bookings list
    ref.invalidate(bookingsProvider);
    
    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('New booking received!')),
    );
  }
  
  void _onBookingUpdated(dynamic data) {
    // Refresh bookings list
    ref.invalidate(bookingsProvider);
  }
  
  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings'),
        actions: [
          // Connection status indicator
          Consumer(builder: (context, ref, child) {
            final status = ref.watch(webSocketStatusProvider);
            return Icon(
              status == WebSocketStatus.connected 
                ? Icons.wifi 
                : Icons.wifi_off,
              color: status == WebSocketStatus.connected 
                ? Colors.green 
                : Colors.red,
            );
          }),
        ],
      ),
      body: BookingsList(bookings: bookings),
    );
  }
}
```

## Example: Chat Screen

```dart
class ChatScreen extends ConsumerStatefulWidget {
  final String eventId;
  
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // Join event room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ref.read(webSocketServiceProvider);
      socket.joinEvent(widget.eventId);
      
      // Listen for messages
      socket.on('new_message', _onNewMessage);
    });
  }
  
  @override
  void dispose() {
    // Leave event room
    final socket = ref.read(webSocketServiceProvider);
    socket.leaveEvent(widget.eventId);
    socket.off('new_message');
    
    _controller.dispose();
    super.dispose();
  }
  
  void _onNewMessage(dynamic data) {
    setState(() {
      _messages.add(ChatMessage.fromJson(data));
    });
  }
  
  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    
    final socket = ref.read(webSocketServiceProvider);
    socket.sendChatMessage(widget.eventId, _controller.text);
    
    _controller.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) => MessageBubble(_messages[index]),
          ),
        ),
        TextField(
          controller: _controller,
          onSubmitted: (_) => _sendMessage(),
          decoration: InputDecoration(
            hintText: 'Type a message...',
            suffixIcon: IconButton(
              icon: Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ),
        ),
      ],
    );
  }
}
```

## Reconnection

The WebSocket service automatically reconnects if the connection is lost:

- **Attempts**: 5 reconnection attempts
- **Delay**: Starts at 1 second, max 5 seconds
- **Room restoration**: Re-joins venue/event rooms after reconnect

## Error Handling

### Connection Errors

```dart
final socket = ref.read(webSocketServiceProvider);

socket.on('error', (error) {
  print('WebSocket error: $error');
  // Show error message to user
});
```

### Authentication Errors

If the token is invalid or expired, the server disconnects the socket:

```dart
// The session controller handles this automatically:
// 1. HTTP API returns 401
// 2. Session controller signs out
// 3. WebSocket disconnects
```

## Best Practices

### 1. Subscribe Only When Needed

Join rooms when the screen appears, leave when it disappears:

```dart
@override
void initState() {
  super.initState();
  socket.joinVenue(venueId);
}

@override
void dispose() {
  socket.leaveVenue();
  super.dispose();
}
```

### 2. Clean Up Listeners

Remove listeners when the screen is disposed:

```dart
@override
void dispose() {
  socket.off('new_booking');
  socket.off('booking_updated');
  super.dispose();
}
```

### 3. Handle Disconnections

Check connection status before sending messages:

```dart
if (socket.isConnected) {
  socket.sendChatMessage(eventId, message);
} else {
  // Show error or queue message
}
```

### 4. Refresh Data on Events

Use WebSocket events to invalidate Riverpod providers:

```dart
socket.on('new_booking', (_) {
  ref.invalidate(bookingsProvider);
});
```

### 5. Show Connection Status

Display a visual indicator so users know if real-time updates are active:

```dart
final status = ref.watch(webSocketStatusProvider);
Icon(
  status == WebSocketStatus.connected ? Icons.wifi : Icons.wifi_off,
  color: status == WebSocketStatus.connected ? Colors.green : Colors.red,
);
```

## Server-Side Events

The Express backend emits these events:

| Event | Room | Payload | Description |
|-------|------|---------|-------------|
| `new_booking` | `restaurant_<id>` | `{bookingId, eventId, guestName, ...}` | New reservation created |
| `booking_updated` | `event_<id>` | `{bookingId, status, ...}` | Booking status changed |
| `event_updated` | `event_<id>` | `{eventId, status, ...}` | Event details changed |
| `new_message` | `event_<id>` | `{eventId, text, userId, sentAt}` | Chat message sent |
| `notification` | `restaurant_<id>` | `{type, message, ...}` | Platform/venue notification |

## Testing

### Manual Testing

1. Start the server: `cd DineCircle-master/server && npm run dev`
2. Run the partner app: `cd partnerapp && flutter run`
3. Login with test credentials
4. Open browser console to see WebSocket logs
5. Create a booking in the customer app
6. Verify partner app receives `new_booking` event

### Automated Testing

```dart
test('WebSocket connects on sign-in', () async {
  final socket = WebSocketService.instance;
  await socket.connect(testToken);
  
  expect(socket.status, WebSocketStatus.connected);
  
  socket.disconnect();
});

test('WebSocket joins venue room', () async {
  final socket = WebSocketService.instance;
  await socket.connect(testToken);
  
  socket.joinVenue('venue-id');
  expect(socket.currentVenueId, 'venue-id');
  
  socket.leaveVenue();
  expect(socket.currentVenueId, isNull);
});
```

## Troubleshooting

### Connection Fails

**Symptom**: Status stays at `connecting` or `error`

**Solutions**:
1. Check server is running: `curl http://192.168.100.70:4000/api/health`
2. Verify token is valid: `curl -H "Authorization: Bearer TOKEN" http://192.168.100.70:4000/api/auth/me`
3. Check CORS configuration in `server.ts`
4. Review server logs for WebSocket errors

### Events Not Received

**Symptom**: Connected but no events arrive

**Solutions**:
1. Verify room subscription: `socket.joinVenue(venueId)`
2. Check event listener registration: `socket.on('event_name', callback)`
3. Confirm server is emitting events (check server logs)
4. Test with customer app to verify server-side functionality

### Frequent Disconnections

**Symptom**: Connection drops repeatedly

**Solutions**:
1. Check network stability
2. Increase reconnection attempts in `websocket_service.dart`
3. Review server logs for authentication errors
4. Verify token hasn't expired

## Resources

- **Service Implementation**: `partnerapp/lib/services/websocket_service.dart`
- **Provider Setup**: `partnerapp/lib/providers/app_providers.dart`
- **Server WebSocket Code**: `DineCircle-master/server/src/server.ts`
- **Socket.io Docs**: https://socket.io/docs/v4/

---

**Last Updated**: 2026-11-02  
**Version**: 1.0  
**Status**: ✅ Implemented and Integrated
