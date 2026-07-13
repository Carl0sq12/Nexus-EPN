import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../providers/trip_location_provider.dart';
import '../providers/trip_provider.dart';

/// Completes a trip: status, passenger rating prompts, chat cleanup.
Future<bool> completeTripWithCleanup(
  WidgetRef ref, {
  required Trip trip,
  required String driverId,
}) async {
  final requests = await ref.read(requestsByTripProvider(trip.id).future);
  final accepted = requests
      .where((r) => r.status == AppStrings.statusAccepted)
      .toList();

  await ref.read(tripNotifierProvider.notifier).updateTrip(trip.id, driverId, {
    'status': AppStrings.statusCompleted,
  });
  final nextState = ref.read(tripNotifierProvider);
  if (nextState.hasError) return false;

  final ds = ref.read(notificationRemoteDatasourceProvider);
  for (final request in accepted) {
    ref.invalidate(myRequestsProvider(request.passengerId));
    ref.invalidate(pendingDriverRatingsProvider(request.passengerId));
    try {
      await ds.create(
        userId: request.passengerId,
        title: 'Califica tu viaje',
        body:
            'El viaje ${trip.origin} → ${trip.destination} finalizó. '
            'Califica al conductor.',
        type: 'trip_completed',
        relatedId: trip.id,
      );
      ref.invalidate(notificationsProvider(request.passengerId));
    } catch (_) {}
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

/// Total collected from accepted seats (proposed price or trip price).
double computeTripRevenue(Trip trip, List<TripRequest> acceptedRequests) {
  var total = 0.0;
  for (final request in acceptedRequests) {
    final unit = request.proposedPrice ?? trip.pricePerSeat;
    total += unit * request.passengerCount;
  }
  return total;
}
