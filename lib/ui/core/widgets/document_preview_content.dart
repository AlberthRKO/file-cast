import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

/// Vista local y de solo lectura del contenido extraído de documentos Office.
class DocumentPreviewContent extends StatelessWidget {
  const DocumentPreviewContent({
    required this.content,
    required this.extension,
    super.key,
  });

  final String content;
  final String extension;

  @override
  Widget build(BuildContext context) {
    if (extension == 'xlsx') return _SpreadsheetPreview(content: content);
    final isOffice = extension == 'docx' || extension == 'pptx';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOffice)
          Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Text(
              extension == 'pptx'
                  ? 'Vista de texto de las primeras 20 diapositivas. '
                        'Imágenes y diseño permanecen en el archivo original.'
                  : 'Vista de texto del documento. Imágenes y formato '
                        'avanzado permanecen en el archivo original.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: _PagedTextPreview(
            content: content,
            pageLabel: extension == 'pptx' ? 'Diapositiva' : 'Página',
          ),
        ),
      ],
    );
  }
}

class _PagedTextPreview extends StatelessWidget {
  const _PagedTextPreview({required this.content, required this.pageLabel});

  final String content;
  final String pageLabel;

  List<String> _pages() {
    const targetCharacters = 2400;
    final pages = <String>[];
    for (final explicitPage in content.split('\f')) {
      final buffer = StringBuffer();
      for (final paragraph in explicitPage.split('\n\n')) {
        if (buffer.length > 0 &&
            buffer.length + paragraph.length > targetCharacters) {
          pages.add(buffer.toString().trim());
          buffer.clear();
        }
        if (buffer.length > 0) buffer.write('\n\n');
        buffer.write(paragraph);
      }
      if (buffer.length > 0) pages.add(buffer.toString().trim());
    }
    return pages.isEmpty ? ['Documento sin contenido visible.'] : pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpace.m),
        itemCount: pages.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpace.m),
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                constraints: BoxConstraints(
                  minHeight: constraints.maxWidth * 1.32,
                ),
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      pageLabel + ' ' + (index + 1).toString(),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: AppSpace.m),
                    SelectableText(
                      pages[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpreadsheetPreview extends StatelessWidget {
  const _SpreadsheetPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final sheets = content.split('\f');
    final theme = Theme.of(context);
    return DefaultTabController(
      length: sheets.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: TabBar(
              isScrollable: true,
              tabs: List.generate(sheets.length, (index) {
                final name = sheets[index].split('\n').first;
                return Tab(
                  text: name.isEmpty ? 'Hoja ' + (index + 1).toString() : name,
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Text(
              'Vista de valores: primeras 20 hojas, 200 filas y 32 columnas. '
              'El formato y las fórmulas originales permanecen en el archivo.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: List.generate(
                sheets.length,
                (index) => _SheetGrid(content: sheets[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetGrid extends StatelessWidget {
  const _SheetGrid({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    if (lines.length <= 1) {
      return const Center(child: Text('Esta hoja no tiene celdas visibles.'));
    }
    final rows = List.generate(
      lines.length - 1,
      (index) => lines[index + 1].split('\t'),
    );
    var columns = 0;
    for (final row in rows) {
      if (row.length - 1 > columns) columns = row.length - 1;
    }
    if (columns == 0) {
      return const Center(child: Text('Esta hoja no tiene celdas visibles.'));
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth < 600 ? 150.0 : 180.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 60 + columns * cellWidth,
            child: ListView.builder(
              itemCount: rows.length + 1,
              itemBuilder: (context, index) {
                final row = index == 0 ? const <String>[] : rows[index - 1];
                final header = index == 0;
                return SizedBox(
                  height: AppSize.minTouchTarget,
                  child: Row(
                    children: List.generate(columns + 1, (column) {
                      final value = header
                          ? column == 0
                                ? ''
                                : _columnLabel(column - 1)
                          : column < row.length
                          ? row[column]
                          : '';
                      return Container(
                        width: column == 0 ? 60 : cellWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s,
                          vertical: AppSpace.xs,
                        ),
                        decoration: BoxDecoration(
                          color: header || column == 0
                              ? theme.colorScheme.surfaceContainerHighest
                              : index.isEven
                              ? theme.colorScheme.surface
                              : theme.colorScheme.surfaceContainerLow,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: .5,
                          ),
                        ),
                        child: Tooltip(
                          message: value,
                          child: Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: header || column == 0
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.bodySmall,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _columnLabel(int index) {
    var value = index + 1;
    final label = StringBuffer();
    while (value > 0) {
      value--;
      label.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return label.toString().split('').reversed.join();
  }
}
