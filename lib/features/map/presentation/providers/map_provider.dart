import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
/// Uses a high-frequency, high-accuracy navigation profile (similar to
/// turn-by-turn apps): short distance filter + short update interval so the
/// driver marker moves fluidly instead of jumping every few meters.
final currentLocationStreamProvider = StreamProvider<UserLocation>((
  ref,
) async* {
  final datasource = ref.watch(locationDatasourceProvider);
  final initialPosition = await datasource.getCurrentPosition();
  yield UserLocation(
    latitude: initialPosition.latitude,
    longitude: initialPosition.longitude,
    heading: initialPosition.heading,
  );

  final LocationSettings settings;
  if (Platform.isAndroid) {
    settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
      intervalDuration: const Duration(milliseconds: 700),
    );
  } else if (Platform.isIOS || Platform.isMacOS) {
    settings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 2,
      pauseLocationUpdatesAutomatically: false,
    );
  } else {
    settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
  }

  yield* Geolocator.getPositionStream(locationSettings: settings).map(
    (position) => UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading,
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

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('No se pudo calcular la ruta');
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