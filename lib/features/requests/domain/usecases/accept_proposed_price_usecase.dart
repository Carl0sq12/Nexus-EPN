import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/trip_request.dart';
import '../repositories/request_repository.dart';

/// Parameters for accepting a driver's proposed price.
class AcceptProposedPriceParams extends Equatable {
  final String requestId;
  final String tripId;

  const AcceptProposedPriceParams({
    required this.requestId,
    required this.tripId,
  });

  @override
  List<Object?> get props => [requestId, tripId];
}

/// Use case for passenger confirmation after a price proposal.
class AcceptProposedPriceUseCase
    implements UseCase<TripRequest, AcceptProposedPriceParams> {
  final RequestRepository repository;

  const AcceptProposedPriceUseCase(this.repository);

  @override
  Future<TripRequest> call(AcceptProposedPriceParams params) {
    return repository.acceptProposedPrice(params.requestId, params.tripId);
  }
}
