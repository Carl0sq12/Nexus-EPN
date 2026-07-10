import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/exceptions.dart';

/// Local datasource for device location using Geolocator.
///
/// Requires Android: `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`
/// Requires iOS: `NSLocationWhenInUseUsageDescription` in Info.plist.
class LocationLocalDatasource {
  const LocationLocalDatasource();

  Future<Position> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const ServerException('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
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

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
