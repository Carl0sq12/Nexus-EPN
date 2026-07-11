import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactsDatasource {
  final Databases databases;

  const EmergencyContactsDatasource(this.databases);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionEmergencyContacts;

  Future<List<EmergencyContactModel>> getContacts(String userId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('user_id', userId),
          Query.orderAsc(r'$createdAt'),
        ],
      );
      return response.documents
          .map((d) => EmergencyContactModel.fromJson(normalizeDocument(d)))
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
      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'name': name,
          'phone': phone,
          if (relationship != null) 'relationship': relationship,
        },
        permissions: ownerPermissions(userId),
      );
      return EmergencyContactModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await databases.deleteDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: contactId,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<EmergencyContactModel> updateContact({
    required String contactId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: contactId,
        data: {'name': name, 'phone': phone, 'relationship': relationship},
      );
      return EmergencyContactModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
