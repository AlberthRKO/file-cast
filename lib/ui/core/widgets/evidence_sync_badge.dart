import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';

/// Estado corto y visible de la copia local/remota de una evidencia.
///
/// El estado llega desde la outbox local cuando existe una evidencia capturada
/// en este dispositivo. Así el usuario distingue una evidencia guardada de
/// una que ya fue aceptada por el servidor.
class EvidenceSyncBadge extends StatelessWidget {
  const EvidenceSyncBadge({
    required this.uploadStatus,
    required this.hasLocalCopy,
    this.compact = false,
    super.key,
  });

  final String? uploadStatus;
  final bool hasLocalCopy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = _state(uploadStatus, hasLocalCopy);
    final foreground = switch (state) {
      _EvidenceBadgeState.synced => scheme.primary,
      _EvidenceBadgeState.uploading => scheme.tertiary,
      _EvidenceBadgeState.failed => scheme.error,
      _EvidenceBadgeState.pending => scheme.tertiary,
      _EvidenceBadgeState.local => scheme.onSurfaceVariant,
    };
    final label = switch (state) {
      _EvidenceBadgeState.synced => 'Sincronizada',
      _EvidenceBadgeState.uploading => 'Subiendo',
      _EvidenceBadgeState.failed => 'Error de subida',
      _EvidenceBadgeState.pending => 'Pendiente',
      _EvidenceBadgeState.local => 'Guardada localmente',
    };
    final icon = switch (state) {
      _EvidenceBadgeState.synced => Icons.cloud_done_outlined,
      _EvidenceBadgeState.uploading => Icons.sync_rounded,
      _EvidenceBadgeState.failed => Icons.error_outline_rounded,
      _EvidenceBadgeState.pending => Icons.cloud_upload_outlined,
      _EvidenceBadgeState.local => Icons.phone_android_outlined,
    };
    if (compact) {
      return Tooltip(
        message: label,
        child: Icon(icon, size: 15, color: foreground),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _EvidenceBadgeState _state(String? status, bool local) =>
      switch (status?.toUpperCase()) {
        'AVAILABLE' => _EvidenceBadgeState.synced,
        'UPLOADING' => _EvidenceBadgeState.uploading,
        'ERROR' => _EvidenceBadgeState.failed,
        'PENDING_UPLOAD' => _EvidenceBadgeState.pending,
        _ => local ? _EvidenceBadgeState.local : _EvidenceBadgeState.pending,
      };
}

enum _EvidenceBadgeState { synced, uploading, failed, pending, local }
