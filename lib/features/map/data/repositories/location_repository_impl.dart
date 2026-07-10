import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_datasource.dart';

/// Implementation of [LocationRepository] using Geolocator.
class LocationRepositoryImpl implements LocationRepository {
  final LocationLocalDatasource localDatasource;

  const LocationRepositoryImpl(this.localDatasource);

  @override
  Future<UserLocation> getCurrentLocation() async {
    try {
      final position = await localDatasource.getCurrentPosition();
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
