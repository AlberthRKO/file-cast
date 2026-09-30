import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:flutter/material.dart';

class RequisitionStatusBadge extends StatelessWidget {
  const RequisitionStatusBadge({
    required this.status,
    super.key,
  });

  final RequisitionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (label, color) = switch (status) {
      RequisitionStatus.draft => (
        'Borrador',
        isDark ? theme.colorScheme.secondary : theme.colorScheme.tertiary,
      ),
      RequisitionStatus.inProgress => (
        'En curso',
        isDark ? esam : lunchColor,
      ),
      RequisitionStatus.finalizing => (
        'Finalizando',
        isDark ? theme.colorScheme.tertiary : theme.colorScheme.secondary,
      ),
      RequisitionStatus.finalized => (
        'Finalizada',
        isDark ? textSucces2 : editColor,
      ),
      RequisitionStatus.cancelled => ('Cancelada', theme.colorScheme.error),
    };

    return Semantics(
      label: 'Estado: $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
