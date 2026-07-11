import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

/// Flattens an Appwrite [Document] into a map compatible with existing models.
///
/// Sets `id` from `$id` and `created_at` from `$createdAt`, while keeping the
/// original system keys for callers that read either form.
Map<String, dynamic> normalizeDocument(models.Document document) {
  final map = <String, dynamic>{};
  for (final entry in document.data.entries) {
    if (entry.key.startsWith('\$')) continue;
    map[entry.key] = entry.value;
  }
  map['id'] = document.$id;
  map[r'$id'] = document.$id;
  map['created_at'] = document.$createdAt;
  map[r'$createdAt'] = document.$createdAt;
  return map;
}

/// Document permissions: anyone can read; owner can update/delete.
List<String> ownerPermissions(String userId) {
  return [
    Permission.read(Role.any()),
    Permission.update(Role.user(userId)),
    Permission.delete(Role.user(userId)),
  ];
}

/// Trip docs need authenticated users to adjust seats when a passenger cancels.
List<String> tripDocumentPermissions(String driverId) {
  return [
    Permission.read(Role.any()),
    Permission.update(Role.users()),
    Permission.delete(Role.user(driverId)),
  ];
}

/// Parses `request_stops` stored as a JSON string or already as a List.
List<Map<String, dynamic>> parseStops(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return parseStops(decoded);
    } catch (_) {
      return const [];
    }
  }
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String encodeStops(List<Map<String, dynamic>> stops) => jsonEncode(stops);
