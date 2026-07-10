import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sos_alert.dart';
import '../repositories/sos_repository.dart';

/// Parameters for [SendSosUseCase].
class SendSosParams extends Equatable {
  final String userId;
  final double latitude;
  final double longitude;
  final String message;
  final String type;

  const SendSosParams({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.message,
    required this.type,
  });

  @override
  List<Object?> get props => [userId, latitude, longitude, message, type];
}

/// Use case for sending an SOS emergency alert.
class SendSosUseCase implements UseCase<SosAlert, SendSosParams> {
  final SosRepository repository;

  const SendSosUseCase(this.repository);

  @override
  Future<SosAlert> call(SendSosParams params) {
    return repository.sendSosAlert(
      params.userId,
      params.latitude,
      params.longitude,
      params.message,
      params.type,
    );
  }
}
