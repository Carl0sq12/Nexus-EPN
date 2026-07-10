import 'dart:io';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../../core/errors/failure.dart';
import '../datasources/profile_remote_datasource.dart';

/// Implementation of [ProfileRepository] using [ProfileRemoteDatasource].
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDatasource datasource;

  const ProfileRepositoryImpl(this.datasource);

  @override
  Future<Profile> getProfile(String userId) async {
    try {
      return await datasource.getProfile(userId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Profile> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      return await datasource.updateProfile(userId, fields);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadAvatar(String userId, File file) async {
    try {
      return await datasource.uploadAvatar(userId, file);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
