import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactsDatasource {
  final SupabaseClient client;

  const EmergencyContactsDatasource(this.client);

  Future<List<EmergencyContactModel>> getContacts(String userId) async {
    try {
      final response = await client
          .from('emergency_contacts')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      return (response as List)
          .map(
            (e) => EmergencyContactModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<EmergencyContactModel> addContact({
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      final response = await client
          .from('emergency_contacts')
          .insert({
            'user_id': userId,
            'name': name,
            'phone': phone,
            'relationship': relationship,
          })
          .select()
          .single();
      return EmergencyContactModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await client.from('emergency_contacts').delete().eq('id', contactId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
