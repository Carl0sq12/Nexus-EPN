import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../providers/trip_location_provider.dart';
import '../providers/trip_provider.dart';

Future<void> _notifyPassenger(
  WidgetRef ref, {
  required String passengerId,
  required String title,
  required String body,
  required String preferredType,
  required String tripId,
}) async {
  final ds = ref.read(notificationRemoteDatasourceProvider);
  Future<void> send(String type) {
    return ds.create(
      userId: passengerId,
      title: title,
      body: body,
      type: type,
      relatedId: tripId,
    );
  }

  try {
    await send(preferredType);
  } catch (e) {
    debugPrint('Notify $preferredType failed: $e — fallback to trip');
    try {
      await send('trip');
    } catch (e2) {
      debugPrint('Notify trip fallback failed: $e2');
      rethrow;
    }
  }
  ref.invalidate(notificationsProvider(passengerId));
}

/// Completes a trip: status, passenger rating prompts, chat cleanup.
Future<bool> completeTripWithCleanup(
  WidgetRef ref, {
  required Trip trip,
  required String driverId,
}) async {
  final requests = await ref
      .read(requestRepositoryProvider)
      .getRequestsForTrip(trip.id);
  final accepted = requests
      .where((r) => r.status == AppStrings.statusAccepted)
      .toList();

  await ref.read(tripNotifierProvider.notifier).updateTrip(trip.id, driverId, {
    'status': AppStrings.statusCompleted,
  });
  final nextState = ref.read(tripNotifierProvider);
  if (nextState.hasError) return false;

  for (final request in accepted) {
    ref.invalidate(myRequestsProvider(request.passengerId));
    ref.invalidate(pendingDriverRatingsProvider(request.passengerId));
    try {
      await _notifyPassenger(
        ref,
        passengerId: request.passengerId,
        title: 'Viaje finalizado',
        body:
            'Tu viaje ${trip.origin} → ${trip.destination} finalizó. '
            'Califica al conductor.',
        preferredType: 'trip_completed',
        tripId: trip.id,
      );
    } catch (e) {
      debugPrint('completeTrip notify failed for ${request.passengerId}: $e');
    }
  }

  try {
    await ref.read(chatNotifierProvider.notifier).deleteChatForTrip(trip.id);
  } catch (_) {}

  try {
    await ref.read(tripLocationDatasourceProvider).deleteLocation(trip.id);
  } catch (_) {}

  ref.invalidate(tripByIdProvider(trip.id));
  ref.invalidate(myTripsProvider(driverId));
  ref.invalidate(chatParticipantsProvider(trip.id));
  return true;
}

/// Cancels a trip and notifies passengers. Never opens rating.
Future<bool> cancelTripWithCleanup(
  WidgetRef ref, {
  required Trip trip,
  required String driverId,
}) async {
  final requests = await ref
      .read(requestRepositoryProvider)
      .getRequestsForTrip(trip.id);
  final toNotify = requests
      .where(
        (r) =>
            r.status == AppStrings.statusAccepted ||
            r.status == AppStrings.statusPending ||
            r.status == AppStrings.statusPriceProposed,
      )
      .toList();

  await ref.read(tripNotifierProvider.notifier).deleteTrip(trip.id, driverId);
  final nextState = ref.read(tripNotifierProvider);
  if (nextState.hasError) return false;

  final requestDs = ref.read(requestDatasourceProvider);

  for (final request in toNotify) {
    try {
      await requestDs.updateRequestStatus(
        request.id,
        AppStrings.statusCancelled,
      );
    } catch (e) {
      debugPrint('cancel request ${request.id} failed: $e');
    }
    ref.invalidate(myRequestsProvider(request.passengerId));
    ref.invalidate(pendingDriverRatingsProvider(request.passengerId));
    try {
      await _notifyPassenger(
        ref,
        passengerId: request.passengerId,
        title: 'Viaje cancelado',
        body:
            'El conductor canceló el viaje ${trip.origin} → ${trip.destination}. '
            'Busca otro conductor.',
        preferredType: 'trip_cancelled',
        tripId: trip.id,
      );
    } catch (e) {
      debugPrint('cancelTrip notify failed for ${request.passengerId}: $e');
    }
  }

  try {
    await ref.read(chatNotifierProvider.notifier).deleteChatForTrip(trip.id);
  } catch (_) {}

  try {
    await ref.read(tripLocationDatasourceProvider).deleteLocation(trip.id);
  } catch (_) {}

  ref.invalidate(tripByIdProvider(trip.id));
  ref.invalidate(myTripsProvider(driverId));
  ref.invalidate(requestsByTripProvider(trip.id));
  ref.invalidate(chatParticipantsProvider(trip.id));
  return true;
}

/// Total collected from accepted seats (proposed price or trip price).
double computeTripRevenue(Trip trip, List<TripRequest> acceptedRequests) {
  var total = 0.0;
  for (final request in acceptedRequests) {
    final unit = request.proposedPrice ?? trip.pricePerSeat;
    total += unit * request.passengerCount;
  }
  return total;
}
