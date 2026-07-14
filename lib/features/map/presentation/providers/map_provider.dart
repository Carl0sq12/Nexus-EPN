import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/route_info.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/get_current_location_usecase.dart';
import '../../data/datasources/location_local_datasource.dart';
import '../../data/repositories/location_repository_impl.dart';

/// Provider for the location local datasource.
final locationDatasourceProvider = Provider<LocationLocalDatasource>((ref) {
  return const LocationLocalDatasource();
});

/// Provider for the location repository.
final locationRepositoryProvider = Provider<LocationRepositoryImpl>((ref) {
  return LocationRepositoryImpl(ref.watch(locationDatasourceProvider));
});

/// Provider for [GetCurrentLocationUseCase].
final getCurrentLocationUseCaseProvider = Provider<GetCurrentLocationUseCase>((
  ref,
) {
  return GetCurrentLocationUseCase(ref.watch(locationRepositoryProvider));
});

/// Fetches the current device location.
final currentLocationProvider = FutureProvider<UserLocation>((ref) {
  final useCase = ref.watch(getCurrentLocationUseCaseProvider);
  return useCase(const NoParams());
});

/// Streams the device location while an in-app trip is in progress.
///
/// Yields last-known immediately (when available), then a fresh fix, then the
/// continuous GPS stream — so the UI never sticks on EPN fallbacks while
/// waiting for the first lock.
final currentLocationStreamProvider = StreamProvider<UserLocation>((
  ref,
) async* {
  final datasource = ref.watch(locationDatasourceProvider);

  final lastKnown = await datasource.getLastKnownPosition();
  if (lastKnown != null) {
    yield UserLocation(
      latitude: lastKnown.latitude,
      longitude: lastKnown.longitude,
      heading: lastKnown.heading,
      speed: lastKnown.speed,
    );
  }

  try {
    final fresh = await datasource.getCurrentPosition();
    yield UserLocation(
      latitude: fresh.latitude,
      longitude: fresh.longitude,
      heading: fresh.heading,
      speed: fresh.speed,
    );
  } catch (_) {
    // Keep streaming if lastKnown already painted the map; otherwise rethrow
    // so the UI can show a real error (not a fake campus pin).
    if (lastKnown == null) rethrow;
  }

  yield* datasource.watchPosition().map(
    (position) => UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading,
      speed: position.speed,
    ),
  );
});

/// Fetches an estimated driving route from OSRM for OpenStreetMap points.
final routeInfoProvider = FutureProvider.family<RouteInfo, RouteRequest>((
  ref,
  request,
) async {
  final start = request.origin;
  final end = request.destination;
  final routeCoordinates = [
    start,
    ...request.waypoints,
    end,
  ].map((point) => '${point.longitude},${point.latitude}').join(';');
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '$routeCoordinates?overview=full&geometries=geojson',
  );

  late final http.Response response;
  try {
    response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw Exception(
      'La ruta tardó demasiado (datos lentos). Intenta de nuevo o cambia de red.',
    );
  } on SocketException {
    throw Exception(
      'Sin conexión al servicio de rutas. Revisa tus datos móviles e inténtalo otra vez.',
    );
  }

  if (response.statusCode != 200) {
    throw Exception('No se pudo calcular la ruta (${response.statusCode})');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final routes = data['routes'] as List<dynamic>? ?? [];
  if (routes.isEmpty) {
    throw Exception('No hay ruta disponible para esos puntos');
  }

  final route = routes.first as Map<String, dynamic>;
  final geometry = route['geometry'] as Map<String, dynamic>;
  final coordinates = geometry['coordinates'] as List<dynamic>;
  final points = coordinates.map((coordinate) {
    final pair = coordinate as List<dynamic>;
    return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
  }).toList();

  return RouteInfo(
    points: points,
    distanceMeters: (route['distance'] as num).toDouble(),
    durationSeconds: (route['duration'] as num).toDouble(),
  );
});

/// Resolves a map coordinate into a readable street/sector label.
final reverseGeocodeProvider = FutureProvider.family<String, LatLng>((
  ref,
  point,
) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'format': 'jsonv2',
    'lat': point.latitude.toString(),
    'lon': point.longitude.toString(),
    'zoom': '18',
    'addressdetails': '1',
  });

  final response = await http.get(
    uri,
    headers: const {'Accept-Language': 'es', 'User-Agent': 'NexusCampus/1.0'},
  );
  if (response.statusCode != 200) {
    throw Exception('No se pudo obtener el nombre del punto');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final address = data['address'] as Map<String, dynamic>? ?? {};
  final name = _firstNonEmpty([
    address['road'],
    address['pedestrian'],
    address['footway'],
    address['cycleway'],
    address['path'],
    address['neighbourhood'],
    address['suburb'],
    address['quarter'],
    address['city_district'],
    data['name'],
  ]);
  final area = _firstNonEmpty([
    address['neighbourhood'],
    address['suburb'],
    address['quarter'],
    address['city_district'],
    address['city'],
  ]);

  if (name != null && area != null && name != area) {
    return '$name, $area';
  }
  if (name != null) return name;

  final displayName = data['display_name'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.split(',').take(2).join(',').trim();
  }

  throw Exception('No hay dirección disponible para ese punto');
});

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

class RouteRequest {
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> waypoints;

  const RouteRequest({
    required this.origin,
    required this.destination,
    this.waypoints = const [],
  });

  @override
  bool operator ==(Object other) {
    return other is RouteRequest &&
        other.origin == origin &&
        other.destination == destination &&
        _samePoints(other.waypoints, waypoints);
  }

  @override
  int get hashCode => Object.hashAll([origin, ...waypoints, destination]);
}

bool _samePoints(List<LatLng> a, List<LatLng> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
