import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/map_provider.dart';

/// Map page showing the user's current location with OpenStreetMap tiles.
class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  static const _epnLocation = LatLng(-0.2106, -78.4889);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mapTitle),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: locationAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(AppStrings.loadingLocation),
            ],
          ),
        ),
        error: (e, _) => const _MapFallback(),
        data: (location) {
          final center = LatLng(location.latitude, location.longitude);
          return _MapContent(
            center: center,
            markerIcon: Icons.navigation,
            title: AppStrings.mapTitle,
            subtitle:
                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
          );
        },
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    return const _MapContent(
      center: MapPage._epnLocation,
      markerIcon: Icons.school_outlined,
      title: 'Campus EPN',
      subtitle: 'Activa la ubicación para ver tu posición actual.',
    );
  }
}

class _MapContent extends StatelessWidget {
  final LatLng center;
  final IconData markerIcon;
  final String title;
  final String subtitle;

  const _MapContent({
    required this.center,
    required this.markerIcon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 15.0),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nexuscampus.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 60,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(29, 111, 164, 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(markerIcon, size: 28, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 160,
          child: FloatingActionButton.small(
            heroTag: 'center_location',
            backgroundColor: AppColors.surface,
            onPressed: () {},
            child: const Icon(Icons.my_location, color: AppColors.primary),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(13, 111, 148, 0.08),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
