import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class RemoteDocumentPreviewService {
  const RemoteDocumentPreviewService();

  Future<String?> extractReadableText(String localPath) async {
    final extension = localPath.toLowerCase().split('.').last;
    if (const {'txt', 'csv', 'json', 'xml', 'log'}.contains(extension)) {
      final bytes = await File(localPath).readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (extension != 'docx') return null;
    final bytes = await File(localPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');
    if (document == null) {
      throw const FormatException('El DOCX no contiene word/document.xml.');
    }
    final content = document.content;
    final xml = XmlDocument.parse(utf8.decode(content));
    final paragraphs = xml.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'p')
        .map(
          (paragraph) => paragraph.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join(),
        )
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .join('\n\n');
    return paragraphs.isEmpty
        ? 'El documento no contiene texto previsualizable.'
        : paragraphs;
  }
}
