import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/repositories/sos_repository.dart';
import '../datasources/sos_remote_datasource.dart';

/// Implementation of [SosRepository] using Supabase.
class SosRepositoryImpl implements SosRepository {
  final SosRemoteDatasource remoteDatasource;

  const SosRepositoryImpl(this.remoteDatasource);

  @override
  Future<SosAlert> sendSosAlert(
    String userId,
    double latitude,
    double longitude,
    String message,
    String type,
  ) async {
    try {
      return await remoteDatasource.sendSosAlert(
        userId,
        latitude,
        longitude,
        message,
        type,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
