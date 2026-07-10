import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/profile_model.dart';

/// Remote datasource for profile operations using Supabase.
class ProfileRemoteDatasource {
  final SupabaseClient client;

  const ProfileRemoteDatasource(this.client);

  Future<ProfileModel> getProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return ProfileModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<ProfileModel> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response = await client
          .from('profiles')
          .update(fields)
          .eq('id', userId)
          .select()
          .single();
      return ProfileModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<String> uploadAvatar(String userId, File file) async {
    try {
      await client.storage
          .from('avatars')
          .upload(
            '$userId.jpg',
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl = client.storage
          .from('avatars')
          .getPublicUrl('$userId.jpg');
      return publicUrl;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
