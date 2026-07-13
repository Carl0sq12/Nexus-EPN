import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
  const interval = Duration(seconds: 4);
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

      // Android can briefly report no GPS/network right after unlocking.
      // Keep the previous usable state until the same problem repeats.
      if (pendingCount >= 2) {
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

Future<bool> _hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup(
      'cloud.appwrite.io',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}
