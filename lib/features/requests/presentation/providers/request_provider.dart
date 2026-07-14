import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../../domain/usecases/send_request_usecase.dart';
import '../../domain/usecases/accept_request_usecase.dart';
import '../../domain/usecases/reject_request_usecase.dart';
import '../../domain/usecases/propose_price_usecase.dart';
import '../../domain/usecases/accept_proposed_price_usecase.dart';
import '../../data/datasources/request_remote_datasource.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../chat/data/datasources/chat_remote_datasource.dart';

/// Provider for the request remote datasource.
final requestDatasourceProvider = Provider<RequestRemoteDatasource>((ref) {
  return RequestRemoteDatasource(ref.watch(databasesProvider));
});

/// Provider for the request repository.
final requestRepositoryProvider = Provider<RequestRepositoryImpl>((ref) {
  return RequestRepositoryImpl(
    ref.watch(requestDatasourceProvider),
    ref.watch(tripDatasourceProvider),
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
      if (stops.isEmpty) {
        throw Exception('Debes marcar tu parada en la ruta antes de solicitar');
      }
      if (stops.length < passengerCount) {
        throw Exception(
          'Marca una parada por cada cupo solicitado antes de enviar',
        );
      }

      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      String passengerName = 'Un pasajero';
      try {
        final profile = await ref.read(profileProvider(passengerId).future);
        passengerName = profile.fullName.trim().isEmpty
            ? passengerName
            : profile.fullName.trim();
      } catch (_) {}

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

      final stopLabel = stops.first.label
          .replaceFirst(RegExp(r'^Tu parada:\s*'), '')
          .trim();
      final seatsLabel = passengerCount == 1
          ? '1 cupo'
          : '$passengerCount cupos';
      try {
        await ref
            .read(notificationRemoteDatasourceProvider)
            .create(
              userId: trip.driverId,
              title: 'Nueva solicitud de $passengerName',
              body:
                  '$passengerName pide $seatsLabel en ${trip.origin} → ${trip.destination}. '
                  'Parada: $stopLabel',
              type: 'trip_request',
              relatedId: tripId,
            );
        ref.invalidate(notificationsProvider(trip.driverId));
      } catch (_) {
        // Request already saved; don't fail the flow if notify fails.
      }

      ref.invalidate(myRequestsProvider(passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(driverIncomingRequestsProvider(trip.driverId));
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
      final request = await ref
          .read(requestRepositoryProvider)
          .getRequestById(requestId);
      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      await ref.read(proposePriceUseCaseProvider)(
        ProposePriceParams(
          requestId: requestId,
          tripId: tripId,
          proposedPrice: proposedPrice,
          priceNote: priceNote,
        ),
      );
      try {
        await ref
            .read(notificationRemoteDatasourceProvider)
            .create(
              userId: request.passengerId,
              title: 'Precio propuesto',
              body:
                  'El conductor propuso \$${proposedPrice.toStringAsFixed(2)} '
                  'por cupo en ${trip.origin} → ${trip.destination}.',
              type: 'price_proposed',
              relatedId: tripId,
            );
        ref.invalidate(notificationsProvider(request.passengerId));
      } catch (_) {}
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(myRequestsProvider(request.passengerId));
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
      if (driverId != null) {
        try {
          String passengerName = 'El pasajero';
          try {
            final profile = await ref.read(profileProvider(passengerId).future);
            passengerName = profile.fullName.trim().isEmpty
                ? passengerName
                : profile.fullName.trim();
          } catch (_) {}
          await ref
              .read(notificationRemoteDatasourceProvider)
              .create(
                userId: driverId,
                title: 'Precio aceptado',
                body: '$passengerName aceptó el precio propuesto',
                type: 'price_accepted',
                relatedId: tripId,
              );
          ref.invalidate(notificationsProvider(driverId));
          final trip = await ref
              .read(tripRepositoryProvider)
              .getTripById(tripId);
          await _announcePassengerJoinedChat(
            ref,
            tripId: tripId,
            trip: trip,
            passengerId: passengerId,
            passengerName: passengerName,
          );
        } catch (_) {}
      }
      ref.invalidate(myRequestsProvider(passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(tripByIdProvider(tripId));
      if (driverId != null) {
        ref.invalidate(myTripsProvider(driverId));
        ref.invalidate(driverIncomingRequestsProvider(driverId));
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptRequest(String requestId, String tripId) async {
    state = const AsyncValue.loading();
    try {
      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      final accepted = await ref.read(acceptRequestUseCaseProvider)(
        AcceptRequestParams(requestId: requestId, tripId: tripId),
      );
      try {
        await ref
            .read(notificationRemoteDatasourceProvider)
            .create(
              userId: accepted.passengerId,
              title: 'Solicitud aceptada',
              body:
                  'Tu solicitud de cupo fue aceptada para '
                  '${trip.origin} → ${trip.destination}.',
              type: 'request_accepted',
              relatedId: tripId,
            );
        ref.invalidate(notificationsProvider(accepted.passengerId));
      } catch (_) {}

      String passengerName = 'Un pasajero';
      try {
        final profile = await ref.read(
          profileProvider(accepted.passengerId).future,
        );
        final name = profile.fullName.trim();
        if (name.isNotEmpty) passengerName = name;
      } catch (_) {}
      await _announcePassengerJoinedChat(
        ref,
        tripId: tripId,
        trip: trip,
        passengerId: accepted.passengerId,
        passengerName: passengerName,
      );

      ref.invalidate(myRequestsProvider(accepted.passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(tripByIdProvider(tripId));
      ref.invalidate(myTripsProvider(trip.driverId));
      ref.invalidate(driverIncomingRequestsProvider(trip.driverId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectRequest(
    String requestId, {
    String? tripId,
    String? passengerId,
  }) async {
    state = const AsyncValue.loading();
    try {
      String? resolvedTripId = tripId;
      String? resolvedPassengerId = passengerId;
      String routeLabel = 'tu viaje';
      try {
        final request = await ref
            .read(requestRepositoryProvider)
            .getRequestById(requestId);
        resolvedTripId ??= request.tripId;
        resolvedPassengerId ??= request.passengerId;
        final trip = await ref
            .read(tripRepositoryProvider)
            .getTripById(request.tripId);
        routeLabel = '${trip.origin} → ${trip.destination}';
      } catch (_) {}

      await ref.read(rejectRequestUseCaseProvider)(
        RejectRequestParams(requestId: requestId),
      );

      if (resolvedPassengerId != null) {
        try {
          await ref
              .read(notificationRemoteDatasourceProvider)
              .create(
                userId: resolvedPassengerId,
                title: 'Solicitud rechazada',
                body: 'Tu solicitud de cupo fue rechazada para $routeLabel.',
                type: 'request_rejected',
                relatedId: resolvedTripId,
              );
          ref.invalidate(notificationsProvider(resolvedPassengerId));
          ref.invalidate(myRequestsProvider(resolvedPassengerId));
        } catch (_) {}
      }
      if (resolvedTripId != null) {
        ref.invalidate(requestsByTripProvider(resolvedTripId));
        try {
          final trip = await ref
              .read(tripRepositoryProvider)
              .getTripById(resolvedTripId);
          ref.invalidate(driverIncomingRequestsProvider(trip.driverId));
        } catch (_) {}
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelRequest(
    String requestId, {
    required String tripId,
    required String passengerId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      String passengerName = 'El pasajero';
      try {
        final profile = await ref.read(profileProvider(passengerId).future);
        passengerName = profile.fullName.trim().isEmpty
            ? passengerName
            : profile.fullName.trim();
      } catch (_) {}
      await ref.read(requestRepositoryProvider).cancelRequest(requestId);
      try {
        await ref
            .read(notificationRemoteDatasourceProvider)
            .create(
              userId: trip.driverId,
              title: 'Solicitud cancelada',
              body: '$passengerName canceló su solicitud',
              type: 'request_cancelled',
              relatedId: tripId,
            );
        ref.invalidate(notificationsProvider(trip.driverId));
      } catch (_) {}
      ref.invalidate(myRequestsProvider(passengerId));
      ref.invalidate(requestsByTripProvider(tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(tripByIdProvider(tripId));
      ref.invalidate(myTripsProvider(trip.driverId));
      ref.invalidate(driverIncomingRequestsProvider(trip.driverId));
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

/// Watches all requests for a given trip (polling).
final requestsByTripProvider = StreamProvider.family<List<TripRequest>, String>(
  (ref, tripId) {
    final repository = ref.watch(requestRepositoryProvider);
    return _pollRequests(() => repository.getRequestsForTrip(tripId));
  },
);

/// Watches all non-finalized requests made by a given passenger (polling).
final myRequestsProvider = StreamProvider.family<List<TripRequest>, String>((
  ref,
  passengerId,
) {
  final repository = ref.watch(requestRepositoryProvider);
  return _pollRequests(() => repository.getMyRequests(passengerId));
});

/// Single request by id.
final requestByIdProvider = FutureProvider.family<TripRequest, String>((
  ref,
  requestId,
) async {
  return ref.watch(requestRepositoryProvider).getRequestById(requestId);
});

/// Incoming seat/cupo requests for the signed-in driver (live polling).
final driverIncomingRequestsProvider =
    StreamProvider.family<List<DriverIncomingRequest>, String>((
      ref,
      driverId,
    ) async* {
      final repository = ref.watch(requestRepositoryProvider);
      final tripRepository = ref.watch(tripRepositoryProvider);
      List<DriverIncomingRequest>? lastGood;

      while (true) {
        try {
          final trips = await tripRepository.getMyTrips(driverId);
          final tripsById = {
            for (final trip in trips)
              if (trip.status == AppStrings.statusActive ||
                  trip.status == AppStrings.statusFull ||
                  trip.status == AppStrings.statusInProgress)
                trip.id: trip,
          };
          final incoming = <DriverIncomingRequest>[];
          if (tripsById.isNotEmpty) {
            final requests = await repository.getRequestsForTrips(
              tripsById.keys,
            );
            for (final request in requests) {
              final trip = tripsById[request.tripId];
              if (trip == null) continue;
              if (request.status == AppStrings.statusPending ||
                  request.status == AppStrings.statusPriceProposed) {
                incoming.add(
                  DriverIncomingRequest(trip: trip, request: request),
                );
              }
            }
            incoming.sort(
              (a, b) => b.request.createdAt.compareTo(a.request.createdAt),
            );
          }
          lastGood = incoming;
          yield incoming;
        } catch (e, st) {
          if (lastGood == null) {
            Error.throwWithStackTrace(e, st);
          }
          yield lastGood;
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    });

/// Unread in-app notifications count (excludes seat/cupo request types).
final unreadNotificationsCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final notifications = ref.watch(notificationsProvider(userId)).asData?.value;
  if (notifications == null) return 0;
  return notifications.where((n) => !n.read).length;
});

/// Badge count for the solicitudes icon (role-aware).
final requestsBadgeCountProvider = Provider.family<int, String>((ref, userId) {
  final profile = ref.watch(profileProvider(userId)).asData?.value;
  if (profile == null) return 0;
  if (profile.role == AppStrings.roleDriver) {
    return ref
            .watch(driverIncomingRequestsProvider(userId))
            .asData
            ?.value
            .length ??
        0;
  }
  final mine = ref.watch(myRequestsProvider(userId)).asData?.value;
  if (mine == null) return 0;
  return mine
      .where(
        (r) =>
            r.status == AppStrings.statusPending ||
            r.status == AppStrings.statusPriceProposed,
      )
      .length;
});

class DriverIncomingRequest {
  final Trip trip;
  final TripRequest request;

  const DriverIncomingRequest({required this.trip, required this.request});
}

Stream<List<TripRequest>> _pollRequests(
  Future<List<TripRequest>> Function() load,
) async* {
  List<TripRequest>? lastGood;
  while (true) {
    try {
      lastGood = await load();
      yield lastGood;
    } catch (e, st) {
      if (lastGood == null) {
        Error.throwWithStackTrace(e, st);
      }
      yield lastGood;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}

final pendingDriverRatingsProvider =
    FutureProvider.family<List<PendingDriverRating>, String>((
      ref,
      passengerId,
    ) async {
      final databases = ref.watch(databasesProvider);
      final ratingDs = ref.watch(ratingDatasourceProvider);
      final db = AppwriteConfig.databaseId;

      final requests = await databases.listDocuments(
        databaseId: db,
        collectionId: AppwriteConfig.collectionTripRequests,
        queries: [
          Query.equal('passenger_id', passengerId),
          Query.equal('status', 'accepted'),
          Query.orderDesc(r'$createdAt'),
        ],
      );

      final pending = <PendingDriverRating>[];
      for (final doc in requests.documents) {
        final json = normalizeDocument(doc);
        final tripId = json['trip_id'] as String;
        try {
          final tripDoc = await databases.getDocument(
            databaseId: db,
            collectionId: AppwriteConfig.collectionTrips,
            documentId: tripId,
          );
          final trip = normalizeDocument(tripDoc);
          // Only completed trips can be rated; cancelled never.
          if (trip['status'] != AppStrings.statusCompleted) continue;

          final driverId = trip['driver_id'] as String;
          final alreadyRated = await ratingDs.hasRating(
            tripId: tripId,
            raterId: passengerId,
            ratedUserId: driverId,
          );
          if (alreadyRated) continue;

          pending.add(
            PendingDriverRating(
              requestId: json['id'] as String,
              tripId: tripId,
              driverId: driverId,
              origin: trip['origin'] as String? ?? '',
              destination: trip['destination'] as String? ?? '',
            ),
          );
        } catch (_) {
          continue;
        }
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

Future<void> _announcePassengerJoinedChat(
  Ref ref, {
  required String tripId,
  required Trip trip,
  required String passengerId,
  required String passengerName,
}) async {
  final name = passengerName.trim().isEmpty
      ? 'Un pasajero'
      : passengerName.trim();
  try {
    final chatDs = ChatRemoteDatasource(
      ref.read(databasesProvider),
      ref.read(realtimeProvider),
    );
    await chatDs.sendSystemMessage(tripId, '$name ingresó al chat');
  } catch (_) {}

  try {
    final ds = ref.read(notificationRemoteDatasourceProvider);
    await ds.create(
      userId: passengerId,
      title: 'Ya puedes chatear',
      body: 'Tu cupo fue aceptado. Entra al chat del viaje para coordinar.',
      type: 'chat',
      relatedId: tripId,
    );
    ref.invalidate(notificationsProvider(passengerId));

    final others = <String>{trip.driverId};
    try {
      final requests = await ref
          .read(requestRepositoryProvider)
          .getRequestsForTrip(tripId);
      for (final request in requests) {
        if (request.status == AppStrings.statusAccepted &&
            request.passengerId != passengerId) {
          others.add(request.passengerId);
        }
      }
    } catch (_) {}

    for (final userId in others) {
      try {
        await ds.create(
          userId: userId,
          title: 'Nuevo integrante en el chat',
          body: '$name ingresó al chat del viaje.',
          type: 'chat',
          relatedId: tripId,
        );
        ref.invalidate(notificationsProvider(userId));
      } catch (_) {}
    }
  } catch (_) {}
}
