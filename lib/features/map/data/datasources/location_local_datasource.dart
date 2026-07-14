import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/exceptions.dart';

/// Local datasource for device location using Geolocator.
///
/// Requires Android: `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`
/// Requires iOS: `NSLocationWhenInUseUsageDescription` in Info.plist.
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

  /// Fast path for UI: last cached GPS fix, if any.
  Future<Position?> getLastKnownPosition() async {
    try {
      await ensurePermission();
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Fresh GPS fix with timeout and Android LocationManager fallback.
  ///
  /// Some devices (e.g. Infinix) hang or fail with Fused Location; we retry
  /// with the platform LocationManager when needed.
  Future<Position> getCurrentPosition() async {
    try {
      await ensurePermission();

      final lastKnown = await Geolocator.getLastKnownPosition();

      try {
        return await _readCurrentPosition(forceLocationManager: false);
      } catch (_) {
        if (Platform.isAndroid) {
          try {
            return await _readCurrentPosition(forceLocationManager: true);
          } catch (_) {
            if (lastKnown != null) return lastKnown;
            rethrow;
          }
        }
        if (lastKnown != null) return lastKnown;
        rethrow;
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<Position> _readCurrentPosition({
    required bool forceLocationManager,
  }) {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: forceLocationManager,
        timeLimit: const Duration(seconds: 15),
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 15),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 15),
      );
    }

    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  /// Live navigation stream after permission is granted.
  Stream<Position> watchPosition() async* {
    await ensurePermission();

    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 800),
        // Prefer Android LocationManager on devices where Fused Location
        // reports stale campus / wrong fixes.
        forceLocationManager: true,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 1,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );
    }

    yield* Geolocator.getPositionStream(locationSettings: settings);
  }
}
