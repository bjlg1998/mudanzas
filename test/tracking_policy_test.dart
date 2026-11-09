import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mudanzas/services/live_tracking_service.dart';

void main() {
  const policy = TrackingPolicy();
  final start = DateTime.utc(2026, 11, 9, 12);
  const initial = LatLng(4.711, -74.0721);

  test('envía la primera ubicación', () {
    expect(
      policy.shouldBroadcast(
        now: start,
        lastSentAt: null,
        current: initial,
        lastSentPosition: null,
      ),
      isTrue,
    );
  });

  test('omite puntos cercanos recibidos antes de diez segundos', () {
    expect(
      policy.shouldBroadcast(
        now: start.add(const Duration(seconds: 5)),
        lastSentAt: start,
        current: const LatLng(4.71101, -74.0721),
        lastSentPosition: initial,
      ),
      isFalse,
    );
  });

  test('envía al cumplir tiempo o distancia', () {
    expect(
      policy.shouldBroadcast(
        now: start.add(const Duration(seconds: 10)),
        lastSentAt: start,
        current: initial,
        lastSentPosition: initial,
      ),
      isTrue,
    );
    expect(
      policy.shouldBroadcast(
        now: start.add(const Duration(seconds: 2)),
        lastSentAt: start,
        current: const LatLng(4.7113, -74.0721),
        lastSentPosition: initial,
      ),
      isTrue,
    );
  });

  test('persiste como máximo una vez por minuto', () {
    expect(policy.shouldPersist(start, null), isTrue);
    expect(
      policy.shouldPersist(start.add(const Duration(seconds: 59)), start),
      isFalse,
    );
    expect(
      policy.shouldPersist(start.add(const Duration(minutes: 1)), start),
      isTrue,
    );
  });
}
