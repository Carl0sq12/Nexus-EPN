import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Place suggestion from OpenStreetMap Nominatim (Quito / Ecuador bias).
class PlaceSuggestion {
  final String displayName;
  final LatLng point;

  const PlaceSuggestion({required this.displayName, required this.point});
}

class GeocodingService {
  GeocodingService._();

  static const _userAgent = 'NexusCampus/1.0 (com.epn.nexus_campus)';

  /// Search places near Quito / EPN.
  static Future<List<PlaceSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$q, Quito, Ecuador',
      'format': 'json',
      'limit': '6',
      'addressdetails': '0',
      'countrycodes': 'ec',
      'viewbox': '-78.60,-0.05,-78.40,-0.35',
      'bounded': '1',
    });

    final response = await http.get(
      uri,
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'es'},
    );
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body);
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((item) {
          final lat = double.tryParse('${item['lat']}');
          final lon = double.tryParse('${item['lon']}');
          final name = '${item['display_name'] ?? ''}';
          if (lat == null || lon == null || name.isEmpty) return null;
          return PlaceSuggestion(
            displayName: name.split(',').take(3).join(',').trim(),
            point: LatLng(lat, lon),
          );
        })
        .whereType<PlaceSuggestion>()
        .toList();
  }

  static Future<String> reverse(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'json',
      'zoom': '17',
    });
    final response = await http.get(
      uri,
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'es'},
    );
    if (response.statusCode != 200) {
      return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
    final data = jsonDecode(response.body);
    if (data is Map && data['display_name'] is String) {
      return (data['display_name'] as String).split(',').take(3).join(',').trim();
    }
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }
}

/// Uber-like fare estimate for campus carpooling (USD).
abstract final class TripFareCalculator {
  static const double baseFare = 0.80;
  static const double perKm = 0.45;
  static const double minimumFare = 1.00;

  static double totalFareFromMeters(double distanceMeters) {
    final km = distanceMeters / 1000.0;
    final total = baseFare + (km * perKm);
    return math.max(minimumFare, _round2(total));
  }

  static double pricePerSeat({
    required double distanceMeters,
    required int seats,
  }) {
    final safeSeats = seats < 1 ? 1 : seats;
    return _round2(totalFareFromMeters(distanceMeters) / safeSeats);
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;
}

/// Geometry helpers for snapping passenger stops onto the driver route.
abstract final class RouteGeometry {
  static LatLng nearestPointOnRoute(LatLng tap, List<LatLng> route) {
    if (route.isEmpty) return tap;
    if (route.length == 1) return route.first;

    var best = route.first;
    var bestDist = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final projected = _projectOnSegment(tap, route[i], route[i + 1]);
      final d = const Distance().as(LengthUnit.Meter, tap, projected);
      if (d < bestDist) {
        bestDist = d;
        best = projected;
      }
    }
    return best;
  }

  /// Max allowed distance (m) from published route for a passenger stop.
  static const maxSnapDistanceMeters = 150.0;

  static bool isNearRoute(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return false;
    final nearest = nearestPointOnRoute(point, route);
    return const Distance().as(LengthUnit.Meter, point, nearest) <=
        maxSnapDistanceMeters;
  }

  static LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return a;
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(ay + clamped * dy, ax + clamped * dx);
  }

  static String encodePoints(List<LatLng> points) => jsonEncode(
        points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      );

  static List<LatLng> decodePoints(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) {
            final lat = (e['lat'] as num?)?.toDouble();
            final lng = (e['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return LatLng(lat, lng);
          })
          .whereType<LatLng>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
