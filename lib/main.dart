import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// Entrypoint del aplicativo. Inicializa Supabase y arranca la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'Faltan SUPABASE_URL o SUPABASE_ANON_KEY en el archivo .env',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // Evita el error de code_verifier cuando el link de confirmación/recovery
        // se abre en un navegador distinto al dispositivo donde se generó el
        // signUp/resetPassword.
        authFlowType: AuthFlowType.implicit,
      ),
    );
    runApp(const ProviderScope(child: NexusCampusApp()));
  } catch (e, stackTrace) {
    // Si algo falla acá (falta el .env, mala config, etc.)
    // esto es justo lo que antes te dejaba pantalla negra sin explicación.
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
