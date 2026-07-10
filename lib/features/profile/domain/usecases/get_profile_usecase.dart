import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// Parameters for [GetProfileUseCase].
class GetProfileParams extends Equatable {
  final String userId;

  const GetProfileParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Use case for fetching a user profile by ID.
class GetProfileUseCase implements UseCase<Profile, GetProfileParams> {
  final ProfileRepository repository;

  const GetProfileUseCase(this.repository);

  @override
  Future<Profile> call(GetProfileParams params) {
    return repository.getProfile(params.userId);
  }
}
