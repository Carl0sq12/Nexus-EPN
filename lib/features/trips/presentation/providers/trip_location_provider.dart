import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/appwrite_provider.dart';
import '../../data/datasources/trip_location_remote_datasource.dart';
import '../../data/models/trip_location_model.dart';

final tripLocationDatasourceProvider = Provider<TripLocationRemoteDatasource>((
  ref,
) {
  return TripLocationRemoteDatasource(
    databases: ref.watch(databasesProvider),
    realtime: ref.watch(realtimeProvider),
  );
});

final tripLocationStreamProvider =
    StreamProvider.family<TripLocationModel?, String>((ref, tripId) {
      return ref.watch(tripLocationDatasourceProvider).watchLocation(tripId);
    });

final recentTripLocationsStreamProvider =
    StreamProvider<List<TripLocationModel>>((ref) {
      return ref.watch(tripLocationDatasourceProvider).watchRecentLocations();
    });
