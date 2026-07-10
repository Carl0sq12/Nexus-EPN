import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/trip_request.dart';
import '../repositories/request_repository.dart';

/// Parameters for proposing a custom request price.
class ProposePriceParams extends Equatable {
  final String requestId;
  final String tripId;
  final double proposedPrice;
  final String? priceNote;

  const ProposePriceParams({
    required this.requestId,
    required this.tripId,
    required this.proposedPrice,
    this.priceNote,
  });

  @override
  List<Object?> get props => [requestId, tripId, proposedPrice, priceNote];
}

/// Use case for sending a driver price proposal.
class ProposePriceUseCase implements UseCase<TripRequest, ProposePriceParams> {
  final RequestRepository repository;

  const ProposePriceUseCase(this.repository);

  @override
  Future<TripRequest> call(ProposePriceParams params) {
    return repository.proposePrice(
      params.requestId,
      params.tripId,
      proposedPrice: params.proposedPrice,
      priceNote: params.priceNote,
    );
  }
}
