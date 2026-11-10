import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

/// Shared rename form for evidence shown from detail and acquisition flows.
///
/// Only the visible base name can be edited. The file extension is derived
/// from the original evidence name and appended to the returned value.
class EvidenceRenameSheet extends StatefulWidget {
  const EvidenceRenameSheet({
    required this.currentName,
    required this.originalName,
    required this.onSave,
    super.key,
  });

  final String currentName;
  final String originalName;
  final Future<String?> Function(String displayName) onSave;

  @override
  State<EvidenceRenameSheet> createState() => _EvidenceRenameSheetState();
}

class _EvidenceRenameSheetState extends State<EvidenceRenameSheet> {
  static const _maximumFullNameLength = 255;

  late final String _extension;
  late final TextEditingController _controller;
  bool _isSaving = false;

  bool get _canSave {
    final baseName = _controller.text.trim();
    return baseName.isNotEmpty &&
        baseName.length + _extension.length <= _maximumFullNameLength;
  }

  int get _maximumBaseNameLength {
    final available = _maximumFullNameLength - _extension.length;
    return available > 0 ? available : 1;
  }

  @override
  void initState() {
    super.initState();
    final originalParts = _FileNameParts.from(widget.originalName);
    final currentName = widget.currentName.trim();
    final currentParts = _FileNameParts.from(currentName);
    _extension = originalParts.extension.isNotEmpty
        ? originalParts.extension
        : currentParts.extension;
    final hasProtectedExtension =
        _extension.isNotEmpty &&
        currentName.length > _extension.length &&
        currentName.toLowerCase().endsWith(_extension.toLowerCase());
    final baseName = hasProtectedExtension
        ? currentName.substring(0, currentName.length - _extension.length)
        : _extension == currentParts.extension &&
              currentParts.extension.isNotEmpty
        ? currentParts.baseName
        : currentName;
    _controller = TextEditingController(text: baseName)..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppSize.formMaxWidth,
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppSpace.m,
                AppSpace.s,
                AppSpace.m,
                AppSpace.m + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppSize.minTouchTarget,
                        height: AppSize.minTouchTarget,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                        child: Icon(
                          Icons.drive_file_rename_outline_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s),
                      Expanded(
                        child: Text(
                          'Cambiar nombre',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s),
                  Text(
                    'Edita el nombre visible de la evidencia. La extensión del archivo se conserva.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_isSaving,
                    maxLength: _maximumBaseNameLength,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Nombre de evidencia (sin extensión)',
                      suffixText: _extension.isEmpty ? null : _extension,
                      prefixIcon: const Icon(Icons.edit_outlined),
                    ),
                    onSubmitted: (_) {
                      if (_canSave) _save();
                    },
                  ),
                  const SizedBox(height: AppSpace.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpace.s),
                      FilledButton.icon(
                        onPressed: _canSave && !_isSaving ? _save : null,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: AppSize.iconS,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_isSaving ? 'Guardando…' : 'Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final displayName = '${_controller.text.trim()}$_extension';
    setState(() {
      _isSaving = true;
    });
    final error = await widget.onSave(displayName);
    if (!mounted) return;
    if (error != null) {
      Navigator.of(context).pop(error);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

final class _FileNameParts {
  const _FileNameParts({required this.baseName, required this.extension});

  factory _FileNameParts.from(String value) {
    final name = value.trim();
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == name.length - 1) {
      return _FileNameParts(baseName: name, extension: '');
    }
    return _FileNameParts(
      baseName: name.substring(0, dotIndex),
      extension: name.substring(dotIndex),
    );
  }

  final String baseName;
  final String extension;
}
