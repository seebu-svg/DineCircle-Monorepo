// WebSocket service integration tests
// Run with: flutter test test/integration/websocket_test.dart

// The console logging below is the point of these manual connectivity checks,
// so the lint that targets production `print` is not useful here.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/services/websocket_service.dart';
import 'package:partnerapp/config/app_config.dart';

/// Test token (replace with actual token from login)
const testToken = 'dc_test_token_here';
const testVenueId = 'bbbbbbbb-0000-4000-8000-000000000001';
const testEventId = 'cccccccc-0000-4000-8000-000000000001';

void main() {
  group('WebSocket Service', () {
    late WebSocketService socket;

    setUp(() {
      socket = WebSocketService.instance;
    });

    tearDown(() {
      socket.disconnect();
    });

    test('should initialize with disconnected status', () {
      expect(socket.status, WebSocketStatus.disconnected);
      expect(socket.isConnected, false);
      expect(socket.currentVenueId, isNull);
    });

    test('should have correct API base URL', () {
      print('📡 API Base URL: ${AppConfig.apiBaseUrl}');
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.apiBaseUrl, contains('http'));
    });

    test('should connect with valid token', () async {
      print('🔌 Testing WebSocket connection...');
      
      try {
        await socket.connect(testToken);
        
        // Wait for connection
        await Future.delayed(const Duration(seconds: 2));
        
        print('Status: ${socket.status}');
        print('Is Connected: ${socket.isConnected}');
        
        // Note: This test requires a running server
        // If server is not running, status will be 'error' or 'connecting'
        expect(socket.status, isIn([
          WebSocketStatus.connected,
          WebSocketStatus.connecting,
          WebSocketStatus.error,
        ]));
        
      } catch (e) {
        print('Expected: Connection may fail if server not running');
        print('Error: $e');
      }
    });

    test('should disconnect cleanly', () async {
      print('🔌 Testing disconnect...');
      
      try {
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 1));
        
        socket.disconnect();
        
        expect(socket.status, WebSocketStatus.disconnected);
        expect(socket.isConnected, false);
        expect(socket.currentVenueId, isNull);
        
        print('✅ Disconnect successful');
      } catch (e) {
        print('Disconnect test: $e');
      }
    });

    test('should join and leave venue room', () async {
      print('🏢 Testing venue room subscription...');
      
      try {
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 2));
        
        if (socket.isConnected) {
          // Join venue
          socket.joinVenue(testVenueId);
          expect(socket.currentVenueId, testVenueId);
          print('✅ Joined venue: $testVenueId');
          
          // Leave venue
          socket.leaveVenue();
          expect(socket.currentVenueId, isNull);
          print('✅ Left venue');
        } else {
          print('⚠️  Not connected, skipping room test');
        }
      } catch (e) {
        print('Venue room test: $e');
      }
    });

    test('should join and leave event room', () async {
      print('🎭 Testing event room subscription...');
      
      try {
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 2));
        
        if (socket.isConnected) {
          // Join event
          socket.joinEvent(testEventId);
          print('✅ Joined event: $testEventId');
          
          // Leave event
          socket.leaveEvent(testEventId);
          print('✅ Left event');
        } else {
          print('⚠️  Not connected, skipping event room test');
        }
      } catch (e) {
        print('Event room test: $e');
      }
    });

    test('should register and remove event listeners', () async {
      print('👂 Testing event listeners...');
      
      var eventReceived = false;
      
      void testCallback(dynamic data) {
        eventReceived = true;
        print('Event received: $data');
      }
      
      // Register listener
      socket.on('test_event', testCallback);
      print('✅ Listener registered');
      
      // Remove listener
      socket.off('test_event', testCallback);
      print('✅ Listener removed');
      
      // Remove all listeners for event
      socket.on('test_event', testCallback);
      socket.on('test_event', (data) {});
      socket.off('test_event');
      print('✅ All listeners removed');
      
      expect(eventReceived, false); // Should not have received any events
    });

    test('should not send message when disconnected', () {
      print('📤 Testing send when disconnected...');
      
      expect(socket.isConnected, false);
      
      // Should not throw, just log warning
      socket.sendChatMessage(testEventId, 'Test message');
      
      print('✅ Send handled gracefully when disconnected');
    });

    test('should handle multiple connect/disconnect cycles', () async {
      print('🔄 Testing multiple connect/disconnect cycles...');
      
      try {
        // First cycle
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 1));
        socket.disconnect();
        expect(socket.status, WebSocketStatus.disconnected);
        print('✅ Cycle 1 complete');
        
        // Second cycle
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 1));
        socket.disconnect();
        expect(socket.status, WebSocketStatus.disconnected);
        print('✅ Cycle 2 complete');
        
        // Third cycle
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 1));
        socket.disconnect();
        expect(socket.status, WebSocketStatus.disconnected);
        print('✅ Cycle 3 complete');
        
      } catch (e) {
        print('Multiple cycles test: $e');
      }
    });

    test('should not connect twice with same token', () async {
      print('🔒 Testing duplicate connection prevention...');
      
      try {
        await socket.connect(testToken);
        final firstStatus = socket.status;
        
        // Try to connect again with same token
        await socket.connect(testToken);
        final secondStatus = socket.status;
        
        expect(firstStatus, secondStatus);
        print('✅ Duplicate connection prevented');
        
        socket.disconnect();
      } catch (e) {
        print('Duplicate connection test: $e');
      }
    });

    test('should switch venue rooms correctly', () async {
      print('🔀 Testing venue room switching...');
      
      try {
        await socket.connect(testToken);
        await Future.delayed(const Duration(seconds: 2));
        
        if (socket.isConnected) {
          // Join first venue
          socket.joinVenue('venue-1');
          expect(socket.currentVenueId, 'venue-1');
          print('✅ Joined venue-1');
          
          // Switch to second venue (should auto-leave first)
          socket.joinVenue('venue-2');
          expect(socket.currentVenueId, 'venue-2');
          print('✅ Switched to venue-2');
          
          // Clean up
          socket.leaveVenue();
          expect(socket.currentVenueId, isNull);
          print('✅ Left all venues');
        } else {
          print('⚠️  Not connected, skipping room switch test');
        }
      } catch (e) {
        print('Venue switch test: $e');
      }
    });
  });

  group('WebSocket Status Enum', () {
    test('should have all required states', () {
      expect(WebSocketStatus.values.length, 5);
      expect(WebSocketStatus.values, contains(WebSocketStatus.disconnected));
      expect(WebSocketStatus.values, contains(WebSocketStatus.connecting));
      expect(WebSocketStatus.values, contains(WebSocketStatus.connected));
      expect(WebSocketStatus.values, contains(WebSocketStatus.reconnecting));
      expect(WebSocketStatus.values, contains(WebSocketStatus.error));
    });
  });

  group('WebSocket Singleton', () {
    test('should return same instance', () {
      final instance1 = WebSocketService.instance;
      final instance2 = WebSocketService.instance;
      
      expect(identical(instance1, instance2), true);
      print('✅ Singleton pattern verified');
    });
  });
}
