import '../../domain/entities/emergency_contact.dart';
import '../../domain/repositories/emergency_contacts_repository.dart';
import '../datasources/emergency_contacts_datasource.dart';

class EmergencyContactsRepository
    implements EmergencyContactsRepositoryContract {
  final EmergencyContactsDatasource datasource;

  const EmergencyContactsRepository(this.datasource);

  @override
  Future<List<EmergencyContact>> getContacts(String userId) async {
    return datasource.getContacts(userId);
  }

  @override
  Future<EmergencyContact> addContact({
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    return datasource.addContact(
      userId: userId,
      name: name,
      phone: phone,
      relationship: relationship,
    );
  }

  @override
  Future<void> deleteContact(String contactId) async {
    return datasource.deleteContact(contactId);
  }

  @override
  Future<EmergencyContact> updateContact({
    required String contactId,
    required String name,
    required String phone,
    String? relationship,
  }) {
    return datasource.updateContact(
      contactId: contactId,
      name: name,
      phone: phone,
      relationship: relationship,
    );
  }
}
