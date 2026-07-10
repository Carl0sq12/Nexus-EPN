import 'dart:io';
import '../entities/profile.dart';

/// Abstract repository for profile-related operations.
abstract class ProfileRepository {
  /// Fetches a user profile by [userId].
  Future<Profile> getProfile(String userId);

  /// Updates specific [fields] for the profile identified by [userId].
  Future<Profile> updateProfile(String userId, Map<String, dynamic> fields);

  /// Uploads a profile avatar image [file] and returns the public URL.
  Future<String> uploadAvatar(String userId, File file);
}
