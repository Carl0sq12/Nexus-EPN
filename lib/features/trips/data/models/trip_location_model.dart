import '../../../../core/network/appwrite_helpers.dart';
import '../../../map/domain/entities/user_location.dart';

/// Latest driver location persisted in Appwrite for a running trip.
class TripLocationModel {
  final String id;
  final String tripId;
  final String driverId;
  final double latitude;
  final double longitude;
  final double heading;
  final double? speed;
  final DateTime updatedAt;

  const TripLocationModel({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    required this.updatedAt,
  });

  factory TripLocationModel.fromJson(Map<String, dynamic> json) {
    return TripLocationModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      driverId: json['driver_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  UserLocation toUserLocation() {
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      speed: speed,
    );
  }

  static TripLocationModel fromDocument(dynamic document) {
    return TripLocationModel.fromJson(normalizeDocument(document));
  }
}
