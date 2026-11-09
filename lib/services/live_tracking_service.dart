import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';

class TrackingPolicy {
  const TrackingPolicy({
    this.broadcastInterval = const Duration(seconds: 10),
    this.minimumDistanceMeters = 25,
    this.persistInterval = const Duration(minutes: 1),
  });

  final Duration broadcastInterval;
  final double minimumDistanceMeters;
  final Duration persistInterval;

  bool shouldBroadcast({
    required DateTime now,
    required DateTime? lastSentAt,
    required LatLng current,
    required LatLng? lastSentPosition,
  }) {
    if (lastSentAt == null || lastSentPosition == null) return true;
    if (now.difference(lastSentAt) >= broadcastInterval) return true;
    return const Distance().as(LengthUnit.Meter, lastSentPosition, current) >=
        minimumDistanceMeters;
  }

  bool shouldPersist(DateTime now, DateTime? lastPersistedAt) =>
      lastPersistedAt == null ||
      now.difference(lastPersistedAt) >= persistInterval;
}

class LiveTrackingService {
  LiveTrackingService({this.policy = const TrackingPolicy()});

  final TrackingPolicy policy;
  RealtimeChannel? _channel;
  DateTime? _lastSentAt;
  DateTime? _lastPersistedAt;
  LatLng? _lastSentPosition;

  Future<void> start(String moveId) async {
    await stop();
    _channel = Backend.client.channel(
      'move:$moveId',
      opts: const RealtimeChannelConfig(private: true),
    )..subscribe();
  }

  Future<bool> publish({
    required String moveId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    final channel = _channel;
    if (channel == null) throw StateError('El seguimiento no ha iniciado.');

    final now = capturedAt ?? DateTime.now().toUtc();
    final position = LatLng(latitude, longitude);
    if (!policy.shouldBroadcast(
      now: now,
      lastSentAt: _lastSentAt,
      current: position,
      lastSentPosition: _lastSentPosition,
    )) {
      return false;
    }

    await channel.sendBroadcastMessage(
      event: 'driver_location',
      payload: {
        'move_id': moveId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed': speed,
        'accuracy': accuracy,
        'captured_at': now.toIso8601String(),
      },
    );
    _lastSentAt = now;
    _lastSentPosition = position;

    if (policy.shouldPersist(now, _lastPersistedAt)) {
      await Backend.client.rpc<void>(
        'record_driver_location',
        params: {
          'p_move_id': moveId,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_heading': heading,
          'p_speed': speed,
          'p_accuracy': accuracy,
          'p_captured_at': now.toIso8601String(),
        },
      );
      _lastPersistedAt = now;
    }
    return true;
  }

  RealtimeChannel listen(
    String moveId,
    void Function(Map<String, dynamic> payload) onLocation,
  ) {
    final channel =
        Backend.client
            .channel(
              'move:$moveId',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(event: 'driver_location', callback: onLocation)
          ..subscribe();
    _channel = channel;
    return channel;
  }

  Future<void> stop() async {
    final channel = _channel;
    if (channel != null && Backend.isConfigured) {
      await Backend.client.removeChannel(channel);
    }
    _channel = null;
    _lastSentAt = null;
    _lastPersistedAt = null;
    _lastSentPosition = null;
  }
}
