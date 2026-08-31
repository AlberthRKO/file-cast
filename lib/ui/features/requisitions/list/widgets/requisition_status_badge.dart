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
    final isFinalized = status == RequisitionStatus.finalized;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isFinalized
        ? (isDark ? textSucces2 : editColor)
        : (isDark ? esam : lunchColor);

    return Semantics(
      label: 'Estado: ${isFinalized ? 'Finalizada' : 'En curso'}',
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
                isFinalized ? 'Finalizada' : 'En curso',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
