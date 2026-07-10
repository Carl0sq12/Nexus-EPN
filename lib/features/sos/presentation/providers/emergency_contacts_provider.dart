import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../data/datasources/emergency_contacts_datasource.dart';
import '../../data/repositories/emergency_contacts_repository_impl.dart';

final emergencyContactsDatasourceProvider =
    Provider<EmergencyContactsDatasource>(
      (ref) => EmergencyContactsDatasource(ref.watch(supabaseClientProvider)),
    );

final emergencyContactsRepositoryProvider =
    Provider<EmergencyContactsRepository>(
      (ref) => EmergencyContactsRepository(
        ref.watch(emergencyContactsDatasourceProvider),
      ),
    );

final emergencyContactsProvider =
    FutureProvider.family<List<EmergencyContact>, String>((ref, userId) async {
      return ref.watch(emergencyContactsRepositoryProvider).getContacts(userId);
    });

final addEmergencyContactProvider =
    FutureProvider.family<EmergencyContact, Map<String, dynamic>>((
      ref,
      params,
    ) async {
      return ref
          .watch(emergencyContactsRepositoryProvider)
          .addContact(
            userId: params['userId'] as String,
            name: params['name'] as String,
            phone: params['phone'] as String,
            relationship: params['relationship'] as String?,
          );
    });

final deleteEmergencyContactProvider = FutureProvider.family<void, String>((
  ref,
  contactId,
) async {
  return ref
      .watch(emergencyContactsRepositoryProvider)
      .deleteContact(contactId);
});
