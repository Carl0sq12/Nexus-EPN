import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/exceptions.dart';

/// Local datasource for device location using Geolocator (Fused / high accuracy).
class LocationLocalDatasource {
  const LocationLocalDatasource();

  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const ServerException('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const ServerException('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const ServerException(
        'Location permissions are permanently denied',
      );
    }
  }

  /// Fresh GPS fix. Retries until accuracy is usable (home map + SOS).
  Future<Position> getCurrentPosition() async {
    try {
      await ensurePermission();

      Position? best;
      for (var attempt = 0; attempt < 3; attempt++) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: _oneShotSettings(),
        );
        if (best == null || position.accuracy < best.accuracy) {
          best = position;
        }
        // Good enough for map/SOS.
        if (position.accuracy > 0 && position.accuracy <= 50) {
          return position;
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      return best!;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Continuous GPS updates for home map and trip navigation.
  Stream<Position> watchPosition() async* {
    await ensurePermission();
    yield* Geolocator.getPositionStream(locationSettings: _streamSettings());
  }

  LocationSettings _oneShotSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 20),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 20),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 20),
    );
  }

  LocationSettings _streamSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 700),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 1,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
  }
}
