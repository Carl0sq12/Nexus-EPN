import 'dart:io';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../../../core/utils/phone_normalizer.dart';
import '../models/profile_model.dart';

/// Remote datasource for profile operations using Appwrite Databases/Storage.
class ProfileRemoteDatasource {
  final Databases databases;
  final Storage storage;

  const ProfileRemoteDatasource(this.databases, this.storage);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionProfiles;
  String get _bucket => AppwriteConfig.bucketAvatars;

  Future<ProfileModel> getProfile(String userId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: userId,
      );
      return ProfileModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Finds a registered profile whose phone matches [phone].
  Future<ProfileModel?> findByPhone(String phone) async {
    try {
      for (final variant in PhoneNormalizer.lookupVariants(phone)) {
        final result = await databases.listDocuments(
          databaseId: _db,
          collectionId: _col,
          queries: [
            Query.equal('phone', variant),
            Query.limit(1),
          ],
        );
        if (result.documents.isNotEmpty) {
          return ProfileModel.fromJson(
            normalizeDocument(result.documents.first),
          );
        }
      }
      return null;
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? e.toString());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<ProfileModel> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: userId,
        data: fields,
      );
      return ProfileModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<String> uploadAvatar(String userId, File file) async {
    try {
      final fileId = userId;
      try {
        await storage.deleteFile(bucketId: _bucket, fileId: fileId);
      } catch (_) {}

      await storage.createFile(
        bucketId: _bucket,
        fileId: fileId,
        file: InputFile.fromPath(
          path: file.path,
          filename: '$userId.jpg',
        ),
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      return AppwriteConfig.fileViewUrl(_bucket, fileId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
