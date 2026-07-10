import 'dart:io';

// Nombre del archivo final que contendrá todo tu código
const outputFileName = 'contexto_proyecto.md';
final rootDir = Directory.current.path;

// Carpetas que ignoramos porque son pesadas o no contienen código fuente útil
const ignoreDirs = [
  '.dart_tool',
  '.idea',
  '.vscode',
  '.git',
  'build',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  'android/.gradle',
  'ios/Pods',
  'ios/.symlinks',
  'linux',
  'macos',
  'windows',
  'web',
];

// Archivos específicos que no queremos incluir
const ignoreFiles = [
  'pubspec.lock',
  outputFileName,
  'export_context_flutter.dart',
];

// Extensiones permitidas
const allowedExtensions = ['.dart', '.yaml', '.yml', '.json', '.md', '.arb'];

void buildContext(Directory currentDir, IOSink outputSink) {
  final items = currentDir.listSync();

  for (final item in items) {
    final name = item.path.split(Platform.pathSeparator).last;

    if (item is Directory) {
      // Ignorar directorios de la lista y los ocultos (excepto .dart_tool etc ya cubiertos)
      final shouldIgnore = ignoreDirs.any((ignored) => item.path.endsWith(ignored)) ||
          (name.startsWith('.') && !ignoreDirs.contains(name));
      if (!shouldIgnore) {
        buildContext(item, outputSink);
      }
    } else if (item is File) {
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';
      final isAllowedExtension = allowedExtensions.contains(ext);

      // Permitir archivos de configuración (pubspec, analysis_options, etc.)
      final isConfigFile = name.startsWith('.') || name.contains('config') || name == 'pubspec.yaml';

      if (!ignoreFiles.contains(name) && (isAllowedExtension || isConfigFile)) {
        try {
          final content = item.readAsStringSync();
          final relativePath = item.path.replaceFirst('$rootDir${Platform.pathSeparator}', '');

          final separator = '\n\n================================================\n';
          final fileHeader = '📄 ARCHIVO: $relativePath\n================================================\n\n';

          outputSink.write(separator + fileHeader + content);
        } catch (e) {
          stderr.writeln('Error leyendo ${item.path}: $e');
        }
      }
    }
  }
}

void main() {
  final outputFile = File('$rootDir${Platform.pathSeparator}$outputFileName');
  final sink = outputFile.openWrite();

  sink.write('# Contexto Completo del Proyecto Flutter\n');
  stderr.writeln('Recopilando código...');

  buildContext(Directory(rootDir), sink);

  sink.close().then((_) {
    stderr.writeln('Listo. Todo tu código se ha consolidado en el archivo: $outputFileName');
  });
}
