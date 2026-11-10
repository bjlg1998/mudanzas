import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class RouteMetrics {
  const RouteMetrics({
    required this.distanceMeters,
    this.durationSeconds,
    this.estimated = false,
  });

  final int distanceMeters;
  final int? durationSeconds;
  final bool estimated;
}

class RoutePoint {
  const RoutePoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class RouteService {
  Future<List<RoutePoint>> path({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final fallback = [
      RoutePoint(originLatitude, originLongitude),
      RoutePoint(destinationLatitude, destinationLongitude),
    ];
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '$originLongitude,$originLatitude;'
          '$destinationLongitude,$destinationLatitude',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return fallback;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      final route = routes?.firstOrNull as Map<String, dynamic>?;
      final geometry = route?['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) return fallback;
      return coordinates
          .map((coordinate) {
            final values = coordinate as List<dynamic>;
            return RoutePoint(
              (values[1] as num).toDouble(),
              (values[0] as num).toDouble(),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return fallback;
    }
  }

  Future<RouteMetrics> calculate({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '$originLongitude,$originLatitude;'
          '$destinationLongitude,$destinationLatitude',
      {'overview': 'false', 'steps': 'false'},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = body['routes'] as List<dynamic>?;
        final route = routes?.firstOrNull as Map<String, dynamic>?;
        final distance = (route?['distance'] as num?)?.round();
        final duration = (route?['duration'] as num?)?.round();
        if (distance != null && distance > 0) {
          return RouteMetrics(
            distanceMeters: distance,
            durationSeconds: duration,
          );
        }
      }
    } catch (_) {
      // Si el enrutador no responde, conservamos una estimación útil.
    }

    return RouteMetrics(
      distanceMeters: _estimatedRoadDistance(
        originLatitude,
        originLongitude,
        destinationLatitude,
        destinationLongitude,
      ),
      estimated: true,
    );
  }

  int _estimatedRoadDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final straightLine =
        earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return math.max(1, (straightLine * 1.25).round());
  }
}

String distanceLabel(int? meters) {
  if (meters == null) return 'Distancia por calcular';
  final kilometers = meters / 1000;
  return kilometers < 10
      ? '${kilometers.toStringAsFixed(1)} km'
      : '${kilometers.round()} km';
}
