import 'package:appwrite/appwrite.dart';

import '../config/appwrite_config.dart';

/// Singleton Appwrite [Client] initialized from [AppwriteConfig].
class AppwriteClientHolder {
  AppwriteClientHolder._();

  static Client? _client;

  static bool get isInitialized => _client != null;

  static Client get instance {
    final existing = _client;
    if (existing != null) return existing;
    throw StateError(
      'Appwrite Client not initialized. Call AppwriteClientHolder.init() first.',
    );
  }

  static Client init() {
    AppwriteConfig.validate();
    final client = Client()
      ..setEndpoint(AppwriteConfig.endpoint)
      ..setProject(AppwriteConfig.projectId)
      ..setSelfSigned(status: false);
    _client = client;
    return client;
  }
}
