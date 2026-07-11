import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/geo_fare.dart';
import '../../../../core/utils/trip_search.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';

/// Place + published-trip search for passengers.
class DestinationSearchPage extends ConsumerStatefulWidget {
  const DestinationSearchPage({super.key});

  @override
  ConsumerState<DestinationSearchPage> createState() =>
      _DestinationSearchPageState();
}

class _DestinationSearchPageState extends ConsumerState<DestinationSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _placeSuggestions = const [];
  List<Trip> _tripSuggestions = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    final allTrips =
        ref.read(availableTripsProvider).asData?.value ?? const <Trip>[];
    final tripMatches = q.length < 2
        ? const <Trip>[]
        : filterTripsByDestinationQuery(allTrips, q).take(12).toList();

    setState(() {
      _tripSuggestions = tripMatches;
      _error = null;
    });

    if (q.length < 3) {
      setState(() {
        _placeSuggestions = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await GeocodingService.search(q);
        if (!mounted) return;
        setState(() {
          _placeSuggestions = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No se pudo buscar lugares. Intenta de nuevo.';
          _placeSuggestions = const [];
        });
      }
    });
  }

  void _selectTrip(Trip trip) {
    context.go('/trips/${trip.id}');
  }

  void _selectPlace(PlaceSuggestion place) {
    final shortName = place.displayName.split(',').first.trim();
    final query = shortName.isNotEmpty ? shortName : place.displayName;
    context.go(
      '${AppStrings.routeTrips}?q=${Uri.encodeComponent(query)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('¿A dónde vamos?'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                final q = value.trim();
                if (q.length < 2) return;
                if (_tripSuggestions.length == 1) {
                  _selectTrip(_tripSuggestions.first);
                  return;
                }
                context.go(
                  '${AppStrings.routeTrips}?q=${Uri.encodeComponent(q)}',
                );
              },
              decoration: InputDecoration(
                hintText: 'Ej: Solanda, Ajavi, La Carolina...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (_tripSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Viajes publicados',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  for (final trip in _tripSuggestions)
                    ListTile(
                      leading: const Icon(
                        Icons.directions_car_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(trip.destination),
                      subtitle: Text(
                        'Desde ${trip.origin} · \$${trip.pricePerSeat.toStringAsFixed(2)}',
                      ),
                      onTap: () => _selectTrip(trip),
                    ),
                ],
                if (_placeSuggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Lugares',
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                  for (final place in _placeSuggestions)
                    ListTile(
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(place.displayName),
                      onTap: () => _selectPlace(place),
                    ),
                ],
                if (!_loading &&
                    _controller.text.trim().length >= 2 &&
                    _tripSuggestions.isEmpty &&
                    _placeSuggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No hay coincidencias todavía'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
