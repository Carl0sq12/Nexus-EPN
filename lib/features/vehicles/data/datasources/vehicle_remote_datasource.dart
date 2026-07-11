import 'dart:io';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../domain/entities/vehicle.dart';
import '../models/vehicle_model.dart';

/// Remote datasource for vehicle operations using Appwrite Databases/Storage.
class VehicleRemoteDatasource {
  final Databases databases;
  final Storage storage;

  const VehicleRemoteDatasource(this.databases, this.storage);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionVehicles;
  String get _bucket => AppwriteConfig.bucketVehicles;

  Future<VehicleModel?> getMyVehicle(String driverId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [Query.equal('driver_id', driverId), Query.limit(1)],
      );
      if (response.documents.isEmpty) return null;
      return VehicleModel.fromJson(normalizeDocument(response.documents.first));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<VehicleModel> createVehicle(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
    String? licensePhotoUrl,
  ) async {
    try {
      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: {
          'driver_id': driverId,
          'brand': brand,
          'model': model,
          'color': color,
          'plate': plate,
          'approval_status': VehicleApprovalStatus.pending,
          if (licensePhotoUrl != null) 'license_photo_url': licensePhotoUrl,
        },
        permissions: ownerPermissions(driverId),
      );
      return VehicleModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<VehicleModel> updateVehicle(
    String vehicleId,
    Map<String, dynamic> fields,
  ) async {
    try {
      // Do not force pending here: photo-only updates keep current approval.
      // Callers set approval_status explicitly on create / re-registration.
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: vehicleId,
        data: fields,
      );
      return VehicleModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Uploads a vehicle photo. Uses a unique file id so replacements always
  /// produce a new URL (avoids cache + "file already exists" failures).
  Future<String> uploadVehiclePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  }) async {
    return _uploadPhoto(
      legacyFileId: 'vehicles_$vehicleId',
      filename: 'vehicle_$vehicleId.jpg',
      file: file,
      previousUrl: previousUrl,
      ownerUserId: ownerUserId,
    );
  }

  Future<String> uploadLicensePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  }) async {
    return _uploadPhoto(
      legacyFileId: 'vehicle_license_$vehicleId',
      filename: 'license_$vehicleId.jpg',
      file: file,
      previousUrl: previousUrl,
      ownerUserId: ownerUserId,
    );
  }

  Future<String> _uploadPhoto({
    required String legacyFileId,
    required String filename,
    required File file,
    String? previousUrl,
    String? ownerUserId,
  }) async {
    try {
      await _tryDeleteFile(legacyFileId);
      final previousFileId = _fileIdFromViewUrl(previousUrl);
      if (previousFileId != null && previousFileId != legacyFileId) {
        await _tryDeleteFile(previousFileId);
      }

      // Always create a new file id so the stored URL changes and clients
      // (and CachedNetworkImage) load the updated photo.
      final fileId = ID.unique();
      final owner = ownerUserId;
      await storage.createFile(
        bucketId: _bucket,
        fileId: fileId,
        file: InputFile.fromPath(path: file.path, filename: filename),
        permissions: [
          Permission.read(Role.any()),
          if (owner != null) Permission.update(Role.user(owner)),
          if (owner != null) Permission.delete(Role.user(owner)),
          if (owner == null) Permission.update(Role.any()),
          if (owner == null) Permission.delete(Role.any()),
        ],
      );
      final baseUrl = AppwriteConfig.fileViewUrl(_bucket, fileId);
      return '$baseUrl&v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> _tryDeleteFile(String fileId) async {
    try {
      await storage.deleteFile(bucketId: _bucket, fileId: fileId);
    } catch (_) {}
  }

  /// Extracts the Appwrite file id from a `/files/{id}/view` URL.
  static String? _fileIdFromViewUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final match = RegExp(r'/files/([^/?]+)/view').firstMatch(url);
    return match?.group(1);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      VehicleModel? existing;
      try {
        final doc = await databases.getDocument(
          databaseId: _db,
          collectionId: _col,
          documentId: vehicleId,
        );
        existing = VehicleModel.fromJson(normalizeDocument(doc));
      } catch (_) {}

      await databases.deleteDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: vehicleId,
      );

      final fileIds = <String>{
        'vehicles_$vehicleId',
        'vehicle_license_$vehicleId',
        if (_fileIdFromViewUrl(existing?.photoUrl) != null)
          _fileIdFromViewUrl(existing!.photoUrl)!,
        if (_fileIdFromViewUrl(existing?.licensePhotoUrl) != null)
          _fileIdFromViewUrl(existing!.licensePhotoUrl)!,
      };
      for (final fileId in fileIds) {
        await _tryDeleteFile(fileId);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
