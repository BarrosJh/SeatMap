import 'dart:io';
import 'package:flutter/foundation.dart';

class FileSaverHelper {
  static Future<String?> salvarArquivo({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    try {
      String? pastaDestino;

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          pastaDestino = '$userProfile\\Downloads';
        }
      }

      if (pastaDestino == null || !Directory(pastaDestino).existsSync()) {
        pastaDestino = Directory.current.path;
      }

      final caminhoCompleto = '$pastaDestino${Platform.pathSeparator}$nomeArquivo';
      final file = File(caminhoCompleto);
      await file.writeAsBytes(bytes);

      return caminhoCompleto;
    } catch (e) {
      debugPrint('[FileSaverHelper] Erro ao salvar arquivo: $e');
      return null;
    }
  }

  static Future<void> abrirArquivoOuPasta(String caminhoArquivo) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', caminhoArquivo]);
      } catch (e) {
        debugPrint('[FileSaverHelper] Erro ao abrir explorer: $e');
      }
    }
  }
}
