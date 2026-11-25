import 'dart:async';

import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/document_preview_content.dart';
import 'package:flutter/material.dart';
import 'package:offline_document_viewer/offline_document_viewer.dart';

/// Visor Office local. Conserva la lectura básica cuando el motor visual falla.
class OfficeDocumentPreview extends StatefulWidget {
  static const supportedExtensions = <String>{
    'doc',
    'docx',
    'docm',
    'xls',
    'xlsx',
    'xlsm',
    'ppt',
    'pptx',
    'pptm',
    'rtf',
    'csv',
    'tsv',
  };

  const OfficeDocumentPreview({
    required this.path,
    required this.name,
    required this.extension,
    this.fallbackText,
    super.key,
  });

  final String path;
  final String name;
  final String extension;
  final String? fallbackText;

  @override
  State<OfficeDocumentPreview> createState() => _OfficeDocumentPreviewState();
}

class _OfficeDocumentPreviewState extends State<OfficeDocumentPreview> {
  final DocumentViewController _controller = DocumentViewController();
  late DocumentSource _source;
  var _attempt = 0;
  var _truncated = false;

  @override
  void initState() {
    super.initState();
    _source = DocumentSource.file(widget.path, name: widget.name);
  }

  @override
  void didUpdateWidget(covariant OfficeDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.name != widget.name) {
      _source = DocumentSource.file(widget.path, name: widget.name);
      _attempt++;
      _truncated = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    try {
      await _controller.goTo(index);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar de página.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legacyNote = switch (widget.extension) {
      'doc' || 'ppt' =>
        'Formato antiguo: el texto se organiza en secciones para leerlo. '
            'No conserva el diseño ni la paginación original.',
      'xls' =>
        'Formato antiguo: esta vista muestra los valores de las celdas '
            'sin el formato original.',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (legacyNote != null)
          Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Text(
              legacyNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (_truncated)
          Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Text(
              'Vista parcial: el archivo supera el contenido que este visor '
              'puede representar.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: DocumentView(
            key: ValueKey(_attempt),
            source: _source,
            controller: _controller,
            renderTimeout: const Duration(seconds: 60),
            placeholderBuilder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: _buildFailure,
            onReady: (info) {
              if (mounted && info.truncated != _truncated) {
                setState(() => _truncated = info.truncated);
              }
            },
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final info = _controller.info;
            if (_controller.status != DocumentViewStatus.ready ||
                info == null ||
                info.unitCount <= 1) {
              return const SizedBox.shrink();
            }
            final position = _controller.position
                .clamp(0, info.unitCount - 1)
                .toInt();
            final String label;
            if (const {'doc', 'ppt', 'rtf'}.contains(widget.extension)) {
              label = 'Sección ${position + 1}';
            } else if (position < info.outline.length &&
                info.outline[position].trim().isNotEmpty) {
              label = info.outline[position];
            } else {
              label = switch (info.format.family) {
                FormatFamily.excel => 'Hoja ${position + 1}',
                FormatFamily.powerPoint => 'Diapositiva ${position + 1}',
                _ => 'Página ${position + 1}',
              };
            }
            return SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: position > 0
                        ? () => unawaited(_goTo(position - 1))
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$label · ${position + 1}/${info.unitCount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed: position < info.unitCount - 1
                        ? () => unawaited(_goTo(position + 1))
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context, DocumentFailure failure) {
    final fallback = widget.fallbackText;
    if (fallback != null && fallback.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Text(
              'El visor visual no pudo abrir este archivo. '
              'Se muestra una lectura básica.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: DocumentPreviewContent(
              content: fallback,
              extension: widget.extension,
            ),
          ),
        ],
      );
    }

    final message = switch (failure) {
      EncryptedDocumentFailure() =>
        'El documento está protegido o usa una variante antigua no compatible.',
      TooLargeFailure() =>
        'El documento es demasiado grande para abrirlo de forma segura.',
      CorruptDocumentFailure() => 'El documento está dañado o incompleto.',
      SuspiciousArchiveFailure() =>
        'El archivo no superó la revisión de seguridad del visor.',
      NotFoundFailure() => 'Ya no se encuentra la copia local del documento.',
      UnsupportedFormatFailure() =>
        'Este formato no es compatible con el visor.',
      RendererFailure(timedOut: true) =>
        'El visor tardó demasiado. Puedes volver a intentarlo.',
      _ => 'No se pudo mostrar el documento.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: AppSize.minTouchTarget,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpace.m),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.m),
            FilledButton.icon(
              onPressed: () => setState(() {
                _attempt++;
                _truncated = false;
              }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
