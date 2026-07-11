import '../entities/emergency_contact.dart';

abstract class EmergencyContactsRepositoryContract {
  Future<List<EmergencyContact>> getContacts(String userId);

  Future<EmergencyContact> addContact({
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  });

  Future<void> deleteContact(String contactId);

  Future<EmergencyContact> updateContact({
    required String contactId,
    required String name,
    required String phone,
    String? relationship,
  });
}
