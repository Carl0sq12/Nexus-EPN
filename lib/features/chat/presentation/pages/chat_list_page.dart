import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../../../core/providers/appwrite_provider.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.chatTitle),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: userId == null
          ? const Center(child: Text('Inicia sesión para ver tus chats'))
          : _ChatList(userId: userId),
    );
  }
}

class _ChatList extends ConsumerStatefulWidget {
  final String userId;
  const _ChatList({required this.userId});

  @override
  ConsumerState<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<_ChatList> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final databases = ref.read(databasesProvider);
      final db = AppwriteConfig.databaseId;

      final driverResponse = await databases.listDocuments(
        databaseId: db,
        collectionId: AppwriteConfig.collectionTrips,
        queries: [
          Query.equal('driver_id', widget.userId),
          Query.orderDesc('departure_time'),
        ],
      );
      final driverTrips = driverResponse.documents
          .map(normalizeDocument)
          .toList();

      final acceptedRequests = await databases.listDocuments(
        databaseId: db,
        collectionId: AppwriteConfig.collectionTripRequests,
        queries: [
          Query.equal('passenger_id', widget.userId),
          Query.equal('status', 'accepted'),
        ],
      );

      final passengerTripIds = acceptedRequests.documents
          .map((d) => normalizeDocument(d)['trip_id'] as String)
          .toList();

      final passengerTrips = <Map<String, dynamic>>[];
      for (final tripId in passengerTripIds) {
        try {
          final tripDoc = await databases.getDocument(
            databaseId: db,
            collectionId: AppwriteConfig.collectionTrips,
            documentId: tripId,
          );
          passengerTrips.add(normalizeDocument(tripDoc));
        } catch (_) {}
      }

      final allTrips = <Map<String, dynamic>>[
        ...driverTrips,
        ...passengerTrips,
      ].where((t) => t['status'] != 'completed').toList();

      allTrips.sort((a, b) {
        final aTime = DateTime.parse(a['departure_time'] as String);
        final bTime = DateTime.parse(b['departure_time'] as String);
        return bTime.compareTo(aTime);
      });

      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final t in allTrips) {
        if (seen.add(t['id'] as String)) unique.add(t);
      }

      if (mounted) setState(() => _trips = unique);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'No se pudieron cargar las conversaciones',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadTrips, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            Text('No hay conversaciones', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Participá en un viaje para chatear',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        final origin = trip['origin'] as String? ?? '';
        final destination = trip['destination'] as String? ?? '';
        final time = trip['departure_time'] as String? ?? '';
        final tripId = trip['id'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: AppColors.surface,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: const Icon(Icons.chat, color: AppColors.primaryMid),
            ),
            title: Text(
              '$origin → $destination',
              style: AppTextStyles.bodyMedium,
            ),
            subtitle: Text(time, style: AppTextStyles.bodySmall),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
            onTap: () => context.go('/chat/$tripId'),
          ),
        );
      },
    );
  }
}
