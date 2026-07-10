import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../../domain/usecases/send_request_usecase.dart';
import '../../domain/usecases/accept_request_usecase.dart';
import '../../domain/usecases/reject_request_usecase.dart';
import '../../domain/usecases/propose_price_usecase.dart';
import '../../domain/usecases/accept_proposed_price_usecase.dart';
import '../../data/datasources/request_remote_datasource.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../../trips/presentation/providers/trip_provider.dart';

/// Provider for the request remote datasource.
final requestDatasourceProvider = Provider<RequestRemoteDatasource>((ref) {
  return RequestRemoteDatasource(ref.watch(supabaseClientProvider));
});

/// Provider for the request repository.
final requestRepositoryProvider = Provider<RequestRepositoryImpl>((ref) {
  return RequestRepositoryImpl(
    ref.watch(requestDatasourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

/// Provider for [SendRequestUseCase].
final sendRequestUseCaseProvider = Provider<SendRequestUseCase>((ref) {
  return SendRequestUseCase(ref.watch(requestRepositoryProvider));
});

/// Provider for [AcceptRequestUseCase].
final acceptRequestUseCaseProvider = Provider<AcceptRequestUseCase>((ref) {
  return AcceptRequestUseCase(ref.watch(requestRepositoryProvider));
});

/// Provider for [RejectRequestUseCase].
final rejectRequestUseCaseProvider = Provider<RejectRequestUseCase>((ref) {
  return RejectRequestUseCase(ref.watch(requestRepositoryProvider));
});

final proposePriceUseCaseProvider = Provider<ProposePriceUseCase>((ref) {
  return ProposePriceUseCase(ref.watch(requestRepositoryProvider));
});

final acceptProposedPriceUseCaseProvider = Provider<AcceptProposedPriceUseCase>(
  (ref) {
    return AcceptProposedPriceUseCase(ref.watch(requestRepositoryProvider));
  },
);

/// State notifier that manages trip request actions.
class RequestNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  RequestNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> sendRequest(
    String tripId,
    String passengerId, {
    int passengerCount = 1,
    String? pickupNote,
    String? dropoffNote,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    List<TripRequestStop> stops = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(sendRequestUseCaseProvider)(
        SendRequestParams(
          tripId: tripId,
          passengerId: passengerId,
          passengerCount: passengerCount,
          pickupNote: pickupNote,
          dropoffNote: dropoffNote,
          pickupLatitude: pickupLatitude,
          pickupLongitude: pickupLongitude,
          dropoffLatitude: dropoffLatitude,
          dropoffLongitude: dropoffLongitude,
          stops: stops,
        ),
      );
      ref.invalidate(myRequestsProvider(passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> proposePrice(
    String requestId,
    String tripId, {
    required double proposedPrice,
    String? priceNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(proposePriceUseCaseProvider)(
        ProposePriceParams(
          requestId: requestId,
          tripId: tripId,
          proposedPrice: proposedPrice,
          priceNote: priceNote,
        ),
      );
      ref.invalidate(requestsByTripProvider(tripId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptProposedPrice(
    String requestId,
    String tripId,
    String passengerId,
  ) async {
    state = const AsyncValue.loading();
    try {
      String? driverId;
      try {
        final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
        driverId = trip.driverId;
      } catch (_) {}
      await ref.read(acceptProposedPriceUseCaseProvider)(
        AcceptProposedPriceParams(requestId: requestId, tripId: tripId),
      );
      ref.invalidate(myRequestsProvider(passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(tripByIdProvider(tripId));
      if (driverId != null) ref.invalidate(myTripsProvider(driverId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptRequest(String requestId, String tripId) async {
    state = const AsyncValue.loading();
    try {
      String? driverId;
      try {
        final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
        driverId = trip.driverId;
      } catch (_) {}
      await ref.read(acceptRequestUseCaseProvider)(
        AcceptRequestParams(requestId: requestId, tripId: tripId),
      );
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(tripByIdProvider(tripId));
      if (driverId != null) ref.invalidate(myTripsProvider(driverId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(rejectRequestUseCaseProvider)(
        RejectRequestParams(requestId: requestId),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [RequestNotifier] that exposes request send/accept/reject actions.
final requestNotifierProvider =
    StateNotifierProvider<RequestNotifier, AsyncValue<void>>((ref) {
      return RequestNotifier(ref);
    });

/// Watches all requests for a given trip without requiring Supabase Realtime.
final requestsByTripProvider = StreamProvider.family<List<TripRequest>, String>(
  (ref, tripId) {
    final repository = ref.watch(requestRepositoryProvider);
    return _pollRequests(() => repository.getRequestsForTrip(tripId));
  },
);

/// Watches all non-finalized requests made by a given passenger without
/// depending on Supabase Realtime being enabled for the table.
final myRequestsProvider = StreamProvider.family<List<TripRequest>, String>((
  ref,
  passengerId,
) {
  final repository = ref.watch(requestRepositoryProvider);
  return _pollRequests(() => repository.getMyRequests(passengerId));
});

Stream<List<TripRequest>> _pollRequests(
  Future<List<TripRequest>> Function() load,
) async* {
  yield await load();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 3));
    yield await load();
  }
}

final pendingDriverRatingsProvider =
    FutureProvider.family<List<PendingDriverRating>, String>((
      ref,
      passengerId,
    ) async {
      final client = ref.watch(supabaseClientProvider);
      final response = await client
          .from('trip_requests')
          .select(
            'id, trip_id, passenger_id, status, created_at, '
            'trips!inner(id, driver_id, origin, destination, status)',
          )
          .eq('passenger_id', passengerId)
          .eq('status', 'accepted')
          .eq('trips.status', 'completed')
          .order('created_at', ascending: false);

      final pending = <PendingDriverRating>[];
      for (final item in response as List<dynamic>) {
        final json = Map<String, dynamic>.from(item as Map);
        final trip = Map<String, dynamic>.from(json['trips'] as Map);
        final driverId = trip['driver_id'] as String;
        final existingRating = await client
            .from('ratings')
            .select('id')
            .eq('trip_id', json['trip_id'] as String)
            .eq('rater_id', passengerId)
            .eq('rated_user_id', driverId)
            .limit(1);

        if ((existingRating as List).isNotEmpty) continue;

        pending.add(
          PendingDriverRating(
            requestId: json['id'] as String,
            tripId: json['trip_id'] as String,
            driverId: driverId,
            origin: trip['origin'] as String? ?? '',
            destination: trip['destination'] as String? ?? '',
          ),
        );
      }

      return pending;
    });

class PendingDriverRating {
  final String requestId;
  final String tripId;
  final String driverId;
  final String origin;
  final String destination;

  const PendingDriverRating({
    required this.requestId,
    required this.tripId,
    required this.driverId,
    required this.origin,
    required this.destination,
  });
}
