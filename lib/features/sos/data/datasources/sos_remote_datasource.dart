import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/sos_alert_model.dart';

/// Remote datasource for SOS emergency alerts using Supabase.
class SosRemoteDatasource {
  final SupabaseClient client;

  const SosRemoteDatasource(this.client);

  Future<SosAlertModel> sendSosAlert(
    String userId,
    double latitude,
    double longitude,
    String message,
    String type,
  ) async {
    try {
      final response = await client
          .from('sos_alerts')
          .insert({
            'user_id': userId,
            'latitude': latitude,
            'longitude': longitude,
            'message': message,
            'type': type,
          })
          .select()
          .single();
      return SosAlertModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
