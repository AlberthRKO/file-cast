import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:offline_document_viewer/offline_document_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

/// Extrae una vista de lectura de una copia local sin modificar el original.
class RemoteDocumentPreviewService {
  const RemoteDocumentPreviewService();

  static const _maxArchiveBytes = 80 * 1024 * 1024;
  static const _maxFallbackBytes = 4 * 1024 * 1024;
  static const _maxFallbackExpandedBytes = 16 * 1024 * 1024;
  static const _maxXmlBytes = 8 * 1024 * 1024;
  static const _maxTextBytes = 10 * 1024 * 1024;
  static const _maxTabularFallbackBytes = 1024 * 1024;
  static const _maxRows = 200;
  static const _maxColumns = 32;
  static const _maxSheets = 20;
  static Future<void> _purgeQueue = Future<void>.value();

  Future<String?> extractReadableText(String localPath) async {
    final extension = localPath.toLowerCase().split('.').last;
    final file = File(localPath);
    if (const {'txt', 'csv', 'tsv', 'json', 'xml', 'log'}.contains(extension)) {
      if (extension == 'csv' || extension == 'tsv') {
        await purgeOfficeViewerCache();
        if (await file.length() > _maxTabularFallbackBytes) return null;
      }
      if (await file.length() > _maxTextBytes) {
        throw const FormatException(
          'El texto supera el límite de vista previa de 10 MB.',
        );
      }
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    }
    if (const {
      'doc',
      'xls',
      'ppt',
      'docm',
      'xlsm',
      'pptm',
      'rtf',
    }.contains(extension)) {
      await purgeOfficeViewerCache();
      if (await file.length() > _maxArchiveBytes) {
        throw const FormatException(
          'El documento Office supera el límite de vista previa de 80 MB.',
        );
      }
      return null;
    }
    if (!const {'docx', 'xlsx', 'pptx'}.contains(extension)) return null;
    await purgeOfficeViewerCache();
    if (await file.length() > _maxArchiveBytes) {
      throw const FormatException(
        'El documento Office supera el límite de vista previa de 80 MB.',
      );
    }
    if (await file.length() > _maxFallbackBytes) return null;
    final path = file.path;
    try {
      return await Isolate.run(
        () => const RemoteDocumentPreviewService()._extractOffice(
          path,
          extension,
        ),
      );
    } on Object {
      // La extracción anterior es únicamente el respaldo de lectura. El
      // visor principal tiene su propia validación y puede abrir más casos.
      return null;
    }
  }

  /// El visor externo guarda el documento descifrado en su workspace local.
  /// Borrarlo antes de abrir y al cerrar evita retener texto plano en caché.
  Future<void> purgeOfficeViewerCache() {
    final purge = _purgeQueue.then((_) async {
      final cache = await getApplicationCacheDirectory();
      final workspaces = Directory(cache.path + '/odv_workspaces');
      if (await workspaces.exists()) {
        await workspaces.delete(recursive: true);
      }
    });
    _purgeQueue = purge.catchError((Object _) {});
    return purge;
  }

  String? _extractOffice(String path, String extension) {
    final file = File(path);
    if (file.lengthSync() > _maxArchiveBytes) {
      throw const FormatException(
        'El documento Office supera el límite de vista previa de 80 MB.',
      );
    }
    final bytes = file.readAsBytesSync();
    final preflight = DocumentPreflight.inspect(bytes: bytes, fileName: path);
    if (preflight is! PreflightReport ||
        preflight.uncompressedBytes > _maxFallbackExpandedBytes) {
      return null;
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    return switch (extension) {
      'docx' => _readDocx(archive),
      'xlsx' => _readXlsx(archive),
      'pptx' => _readPptx(archive),
      _ => null,
    };
  }

  XmlDocument? _xml(Archive archive, String path) {
    final entry = archive.findFile(path);
    if (entry == null) return null;
    if (entry.size > _maxXmlBytes) {
      throw const FormatException(
        'Una parte del documento supera el límite de vista previa de 8 MB.',
      );
    }
    return XmlDocument.parse(utf8.decode(entry.content));
  }

  String _readDocx(Archive archive) {
    final xml = _xml(archive, 'word/document.xml');
    if (xml == null) {
      throw const FormatException('El DOCX no contiene word/document.xml.');
    }
    final paragraphs = xml.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'p')
        .map((paragraph) => _textNodes(paragraph))
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    return paragraphs.isEmpty
        ? 'El documento no contiene texto previsualizable.'
        : paragraphs;
  }

  String _readPptx(Archive archive) {
    final slides =
        archive.files
            .where(
              (file) =>
                  RegExp(r'^ppt/slides/slide[0-9]+\.xml$').hasMatch(file.name),
            )
            .toList()
          ..sort(
            (a, b) => _numberInName(a.name).compareTo(_numberInName(b.name)),
          );
    if (slides.isEmpty) {
      throw const FormatException('El PPTX no contiene diapositivas legibles.');
    }
    final output = <String>[];
    for (final slideFile in slides.take(_maxSheets)) {
      final slide = _xml(archive, slideFile.name)!;
      final paragraphs = slide.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'p')
          .map(_textNodes)
          .where((text) => text.trim().isNotEmpty)
          .join('\n\n');
      output.add(
        paragraphs.isEmpty ? 'Diapositiva sin texto visible.' : paragraphs,
      );
    }
    return output.join('\f');
  }

  String _readXlsx(Archive archive) {
    final workbook = _xml(archive, 'xl/workbook.xml');
    if (workbook == null) {
      throw const FormatException('El XLSX no contiene xl/workbook.xml.');
    }
    final relationships = _xml(archive, 'xl/_rels/workbook.xml.rels');
    final targets = <String, String>{};
    if (relationships != null) {
      for (final relation
          in relationships.descendants.whereType<XmlElement>()) {
        if (relation.name.local != 'Relationship') continue;
        final id = relation.getAttribute('Id');
        final target = relation.getAttribute('Target');
        if (id != null && target != null) targets[id] = target;
      }
    }
    final sharedStrings = _readSharedStrings(archive);
    final sheets = workbook.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'sheet')
        .take(_maxSheets)
        .toList();
    if (sheets.isEmpty)
      throw const FormatException('El XLSX no contiene hojas.');
    final output = <String>[];
    for (var index = 0; index < sheets.length; index++) {
      final sheet = sheets[index];
      final name = _clean(
        sheet.getAttribute('name') ?? 'Hoja ' + (index + 1).toString(),
      );
      final relationId = _attributeByLocalName(sheet, 'id');
      final target = targets[relationId];
      final sheetPath = target == null
          ? 'xl/worksheets/sheet' + (index + 1).toString() + '.xml'
          : _sheetPath(target);
      final xml = _xml(archive, sheetPath);
      if (xml == null) {
        output.add(name + '\n(hoja no disponible)');
        continue;
      }
      final lines = <String>[name];
      for (final row
          in xml.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 'row')
              .take(_maxRows)) {
        final number = _clean(row.getAttribute('r') ?? lines.length.toString());
        final cells = List<String>.filled(_maxColumns, '');
        var lastColumn = -1;
        var nextColumn = 0;
        for (final cell in row.children.whereType<XmlElement>()) {
          if (cell.name.local != 'c') continue;
          final reference = cell.getAttribute('r');
          final column = reference == null
              ? nextColumn
              : _columnIndex(reference);
          nextColumn = column + 1;
          if (column < 0 || column >= _maxColumns) continue;
          cells[column] = _cellValue(cell, sharedStrings);
          if (column > lastColumn) lastColumn = column;
        }
        if (lastColumn >= 0) {
          lines.add(number + '\t' + cells.take(lastColumn + 1).join('\t'));
        }
      }
      output.add(lines.join('\n'));
    }
    return output.join('\f');
  }

  List<String> _readSharedStrings(Archive archive) {
    final xml = _xml(archive, 'xl/sharedStrings.xml');
    if (xml == null) return const [];
    return xml.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'si')
        .map((element) => _clean(_textNodes(element)))
        .toList();
  }

  String _cellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    final raw = cell.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'v')
        .map((element) => element.innerText)
        .firstOrNull;
    if (type == 's') {
      final index = int.tryParse(raw ?? '');
      return index != null && index >= 0 && index < sharedStrings.length
          ? sharedStrings[index]
          : '';
    }
    if (type == 'inlineStr') return _clean(_textNodes(cell));
    if (type == 'b') return raw == '1' ? 'VERDADERO' : 'FALSO';
    if (raw == null) {
      final formula = cell.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'f')
          .map((element) => element.innerText)
          .firstOrNull;
      if (formula != null && formula.isNotEmpty) return '=' + _clean(formula);
    }
    return _clean(raw ?? '');
  }

  String _textNodes(XmlElement element) => element.descendants
      .whereType<XmlElement>()
      .where((node) => node.name.local == 't')
      .map((node) => node.innerText)
      .join();

  String? _attributeByLocalName(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  String _sheetPath(String target) {
    final normalized = target
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '');
    if (normalized.contains('..')) {
      throw const FormatException('Ruta de hoja XLSX inválida.');
    }
    return normalized.startsWith('xl/') ? normalized : 'xl/' + normalized;
  }

  int _columnIndex(String reference) {
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(reference);
    if (letters == null) return -1;
    var index = 0;
    for (final unit in letters.toUpperCase().codeUnits) {
      index = index * 26 + unit - 64;
    }
    return index - 1;
  }

  int _numberInName(String path) =>
      int.tryParse(
        RegExp(r'[0-9]+(?=\.xml$)').firstMatch(path)?.group(0) ?? '',
      ) ??
      0;

  String _clean(String value) =>
      value.replaceAll(RegExp(r'[\t\n\r\f]+'), ' ').trim();
}
