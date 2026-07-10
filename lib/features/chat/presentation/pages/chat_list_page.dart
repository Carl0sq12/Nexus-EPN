import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;

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

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      final driverTrips = await client
          .from('trips')
          .select()
          .eq('driver_id', widget.userId)
          .order('departure_time', ascending: false);

      final acceptedRequests = await client
          .from('trip_requests')
          .select('trip_id')
          .eq('passenger_id', widget.userId)
          .eq('status', 'accepted');

      final passengerTripIds = (acceptedRequests as List)
          .map((r) => r['trip_id'] as String)
          .toList();

      List<Map<String, dynamic>> passengerTrips = [];
      if (passengerTripIds.isNotEmpty) {
        final response = await client
            .from('trips')
            .select()
            .inFilter('id', passengerTripIds)
            .order('departure_time', ascending: false);
        passengerTrips = (response as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final allTrips = <Map<String, dynamic>>[
        ...(driverTrips as List).map((e) => Map<String, dynamic>.from(e)),
        ...passengerTrips,
      ];

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
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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
