import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

class MirrorDiagnosticsPanel extends StatelessWidget {
  const MirrorDiagnosticsPanel({
    required this.log,
    required this.onRefresh,
    required this.onClose,
    super.key,
  });

  final String log;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .88),
    borderRadius: BorderRadius.circular(AppRadius.m),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Colors.white70, size: 18),
              const SizedBox(width: AppSpace.xs),
              const Expanded(
                child: Text(
                  'Diagnóstico de control',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Actualizar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                log.isEmpty ? 'Recopilando datos…' : log,
                style: TextStyle(
                  color: Colors.green.shade200,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
