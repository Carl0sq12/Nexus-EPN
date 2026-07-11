import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../ratings/domain/entities/rating.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../providers/trip_provider.dart';
import '../utils/trip_completion.dart';

/// Post-trip record for the driver: passengers, stops, ratings, revenue.
class TripReportPage extends ConsumerWidget {
  final String tripId;

  const TripReportPage({required this.tripId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final requestsAsync = ref.watch(requestsByTripProvider(tripId));
    final ratingsAsync = ref.watch(ratingsForTripProvider(tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reporte del viaje'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: tripAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(tripByIdProvider(tripId)),
        ),
        data: (trip) {
          return requestsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => AppErrorView(message: e.toString()),
            data: (requests) {
              final accepted = requests
                  .where((r) => r.status == AppStrings.statusAccepted)
                  .toList();
              final ratings = ratingsAsync.asData?.value ?? <Rating>[];
              final total = computeTripRevenue(trip, accepted);
              final time = DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(trip.departureTime);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ruta', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${trip.origin} → ${trip.destination}',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Salida: $time',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Total recaudado',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Pasajeros y paradas', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  if (accepted.isEmpty)
                    Text(
                      'No hubo pasajeros aceptados.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    for (final request in accepted) ...[
                      _PassengerReportTile(
                        request: request,
                        tripPrice: trip.pricePerSeat,
                        rating: _ratingFromPassenger(ratings, request.passengerId),
                      ),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 8),
                  Text(
                    'El chat de este viaje se eliminó al completarlo. '
                    'Este reporte queda como registro.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Rating? _ratingFromPassenger(List<Rating> ratings, String passengerId) {
    for (final rating in ratings) {
      if (rating.raterId == passengerId) return rating;
    }
    return null;
  }
}

class _PassengerReportTile extends ConsumerWidget {
  final TripRequest request;
  final double tripPrice;
  final Rating? rating;

  const _PassengerReportTile({
    required this.request,
    required this.tripPrice,
    required this.rating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(request.passengerId)).asData?.value;
    final name = (profile?.fullName.trim().isNotEmpty ?? false)
        ? profile!.fullName.trim()
        : 'Pasajero';
    final stop = request.stops.isNotEmpty
        ? request.stops.first.label
            .replaceFirst(RegExp(r'^Tu parada:\s*'), '')
            .trim()
        : (request.pickupNote?.trim().isNotEmpty ?? false)
            ? request.pickupNote!.trim()
            : 'Sin parada';
    final unit = request.proposedPrice ?? tripPrice;
    final amount = unit * request.passengerCount;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name[0].toUpperCase(),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.labelMedium),
                    Text(
                      '${request.passengerCount} cupo(s) · \$${amount.toStringAsFixed(2)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (rating != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 18),
                    Text('${rating!.score}', style: AppTextStyles.labelMedium),
                  ],
                )
              else
                Text(
                  'Sin calificar',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Parada: $stop',
            style: AppTextStyles.bodySmall,
          ),
          if (rating?.comment != null && rating!.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"${rating!.comment}"',
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}
