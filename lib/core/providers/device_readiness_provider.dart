import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../config/appwrite_config.dart';

enum DeviceReadinessIssue {
  none,
  noInternet,
  locationServiceDisabled,
  locationPermissionDenied,
  locationPermissionDeniedForever,
}

class DeviceReadinessState {
  final DeviceReadinessIssue issue;

  const DeviceReadinessState(this.issue);

  bool get isReady => issue == DeviceReadinessIssue.none;
}

final deviceReadinessProvider = StreamProvider<DeviceReadinessState>((ref) {
  return _watchDeviceReadiness();
});

Stream<DeviceReadinessState> _watchDeviceReadiness() async* {
  const interval = Duration(seconds: 5);
  var visibleState = const DeviceReadinessState(DeviceReadinessIssue.none);
  DeviceReadinessIssue? pendingIssue;
  var pendingCount = 0;

  while (true) {
    final checked = await checkDeviceReadiness();
    final issue = checked.issue;

    if (issue == DeviceReadinessIssue.none) {
      pendingIssue = null;
      pendingCount = 0;
      visibleState = checked;
      yield visibleState;
    } else if (_requiresConfirmation(issue)) {
      if (pendingIssue == issue) {
        pendingCount++;
      } else {
        pendingIssue = issue;
        pendingCount = 1;
      }

      // Mobile data / DNS can briefly fail. Require several consecutive
      // failures before blocking the whole app.
      if (pendingCount >= 3) {
        visibleState = checked;
        yield visibleState;
      } else {
        yield visibleState;
      }
    } else {
      pendingIssue = null;
      pendingCount = 0;
      visibleState = checked;
      yield visibleState;
    }

    await Future<void>.delayed(interval);
  }
}

bool _requiresConfirmation(DeviceReadinessIssue issue) {
  return issue == DeviceReadinessIssue.noInternet ||
      issue == DeviceReadinessIssue.locationServiceDisabled;
}

Future<DeviceReadinessState> checkDeviceReadiness() async {
  final hasInternet = await _hasInternetConnection();
  if (!hasInternet) {
    return const DeviceReadinessState(DeviceReadinessIssue.noInternet);
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const DeviceReadinessState(
      DeviceReadinessIssue.locationServiceDisabled,
    );
  }

  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    return const DeviceReadinessState(
      DeviceReadinessIssue.locationPermissionDenied,
    );
  }
  if (permission == LocationPermission.deniedForever) {
    return const DeviceReadinessState(
      DeviceReadinessIssue.locationPermissionDeniedForever,
    );
  }

  return const DeviceReadinessState(DeviceReadinessIssue.none);
}

/// More resilient than a single DNS lookup: mobile carriers often fail or
/// time out looking up one host even when data is working.
Future<bool> _hasInternetConnection() async {
  final hosts = <String>[
    _hostFromEndpoint(AppwriteConfig.endpoint),
    'sfo.cloud.appwrite.io',
    'one.one.one.one',
    'dns.google',
  ].where((h) => h.isNotEmpty).toSet().toList();

  for (final host in hosts) {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException {
      // try next host
    } on TimeoutException {
      // try next host
    } catch (_) {
      // try next host
    }
  }

  // Last resort: open a short TCP/TLS handshake to the Appwrite endpoint.
  try {
    final uri = Uri.parse(AppwriteConfig.endpoint);
    final host = uri.host;
    if (host.isEmpty) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .headUrl(uri.replace(path: '/'))
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      return true;
    } finally {
      client.close(force: true);
    }
  } catch (_) {
    return false;
  }
}

String _hostFromEndpoint(String endpoint) {
  try {
    return Uri.parse(endpoint).host;
  } catch (_) {
    return '';
  }
}
