import 'dart:io';
import 'dart:typed_data';

Future<String> saveExcelFile(String fileName, Uint8List bytes) async {
  final outputDir = await _downloadDirectory();
  final file = File('${outputDir.path}${Platform.pathSeparator}$fileName');
  final saved = await file.writeAsBytes(bytes, flush: true);
  return saved.path;
}

Future<Directory> _downloadDirectory() async {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    final downloads = Directory('$home${Platform.pathSeparator}Downloads');
    try {
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    } catch (_) {
      // Fall back to the current process directory below.
    }
  }
  return Directory.current;
}
