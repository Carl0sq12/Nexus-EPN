import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/appwrite_client.dart';

/// Entrypoint del aplicativo. Inicializa Appwrite y arranca la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true;
  };

  try {
    // Prefer assets/env (incluido en el APK). Fallback a .env local en debug.
    var loaded = false;
    for (final fileName in ['assets/env/appwrite.env', '.env']) {
      try {
        await dotenv.load(fileName: fileName);
        loaded = true;
        break;
      } catch (_) {
        // try next
      }
    }
    if (!loaded) {
      throw Exception(
        'No se pudo cargar la configuracion. Falta assets/env/appwrite.env',
      );
    }
    AppwriteClientHolder.init();
    runApp(const ProviderScope(child: NexusCampusApp()));
  } catch (e, stackTrace) {
    debugPrint('Error inicializando la app: $e');
    debugPrint('$stackTrace');
    runApp(_ErrorApp(error: e.toString()));
  }
}

/// Pantalla simple de error para no dejar la app "congelada" en negro
/// si algo falla durante la inicialización.
class _ErrorApp extends StatelessWidget {
  final String error;
  const _ErrorApp({required this.error});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Error al iniciar la aplicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
