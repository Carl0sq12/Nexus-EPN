import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip_request.dart';
import '../repositories/request_repository.dart';

/// Parameters for [RejectRequestUseCase].
class RejectRequestParams extends Equatable {
  final String requestId;

  const RejectRequestParams({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

/// Use case for rejecting a trip request.
class RejectRequestUseCase
    implements UseCase<TripRequest, RejectRequestParams> {
  final RequestRepository repository;

  const RejectRequestUseCase(this.repository);

  @override
  Future<TripRequest> call(RejectRequestParams params) {
    return repository.rejectRequest(params.requestId);
  }
}
