import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip_request.dart';
import '../repositories/request_repository.dart';

/// Parameters for [AcceptRequestUseCase].
class AcceptRequestParams extends Equatable {
  final String requestId;
  final String tripId;

  const AcceptRequestParams({required this.requestId, required this.tripId});

  @override
  List<Object?> get props => [requestId, tripId];
}

/// Use case for accepting a trip request.
class AcceptRequestUseCase
    implements UseCase<TripRequest, AcceptRequestParams> {
  final RequestRepository repository;

  const AcceptRequestUseCase(this.repository);

  @override
  Future<TripRequest> call(AcceptRequestParams params) {
    return repository.acceptRequest(params.requestId, params.tripId);
  }
}
