// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

class FileSaverHelper {
  static Future<String?> salvarArquivo({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final mimeType = nomeArquivo.endsWith('.xlsx')
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : (nomeArquivo.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream');

    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', nomeArquivo)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    return 'Pasta de Downloads do Navegador';
  }

  static Future<void> abrirArquivoOuPasta(String caminhoArquivo) async {}
}
