import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increments when session-bound data changes and onboarding guards must
/// re-check profile, vehicle or emergency-contact requirements.
final sessionDataVersionProvider = StateProvider<int>((ref) => 0);
