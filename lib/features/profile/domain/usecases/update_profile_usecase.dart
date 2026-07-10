import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// Parameters for [UpdateProfileUseCase].
class UpdateProfileParams extends Equatable {
  final String userId;
  final String? fullName;
  final String? avatarUrl;

  const UpdateProfileParams({
    required this.userId,
    this.fullName,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, fullName, avatarUrl];
}

/// Use case for updating a user profile with optional fields.
class UpdateProfileUseCase implements UseCase<Profile, UpdateProfileParams> {
  final ProfileRepository repository;

  const UpdateProfileUseCase(this.repository);

  @override
  Future<Profile> call(UpdateProfileParams params) {
    final fields = <String, dynamic>{};
    if (params.fullName != null) fields['full_name'] = params.fullName;
    if (params.avatarUrl != null) fields['avatar_url'] = params.avatarUrl;
    return repository.updateProfile(params.userId, fields);
  }
}
