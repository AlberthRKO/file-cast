import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class RequisitionFilters extends StatelessWidget {
  const RequisitionFilters({
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.onStatusChanged,
    required this.onDatePressed,
    required this.onClear,
    this.vertical = false,
    super.key,
  });

  final RequisitionStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<RequisitionStatus?> onStatusChanged;
  final VoidCallback onDatePressed;
  final VoidCallback onClear;
  final bool vertical;

  bool get _hasFilters =>
      status != null || startDate != null || endDate != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusField = DropdownButtonFormField<RequisitionStatus?>(
      key: ValueKey(status),
      initialValue: status,
      style: theme.textTheme.bodyMedium,
      dropdownColor: theme.cardColor,
      iconEnabledColor: theme.primaryColor,
      decoration: InputDecoration(
        labelText: 'Estado',
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.primaryColor.withValues(alpha: 0.55),
        ),
        prefixIcon: _ThemedSvgIcon(assetName: 'estado.svg'),
      ),
      items: const [
        DropdownMenuItem(child: Text('Todos los estados')),
        DropdownMenuItem(
          value: RequisitionStatus.inProgress,
          child: Text('En curso'),
        ),
        DropdownMenuItem(
          value: RequisitionStatus.finalized,
          child: Text('Finalizada'),
        ),
      ],
      onChanged: onStatusChanged,
    );

    final dateField = InkWell(
      onTap: onDatePressed,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha inicio - Fecha fin',
          labelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.primaryColor.withValues(alpha: 0.55),
          ),
          prefixIcon: const _ThemedSvgIcon(assetName: 'calendar.svg'),
        ),
        child: Text(_dateLabel, style: theme.textTheme.bodyMedium),
      ),
    );

    final clearButton = TextButton.icon(
      onPressed: _hasFilters ? onClear : null,
      icon: const Icon(Icons.filter_alt_off_outlined),
      label: const Text('Limpiar'),
    );

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusField,
          const SizedBox(height: AppSpace.m),
          dateField,
          const SizedBox(height: AppSpace.s),
          SizedBox(height: AppSize.minTouchTarget, child: clearButton),
        ],
      );
    }

    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 190, child: statusField),
        SizedBox(width: 240, child: dateField),
        SizedBox(height: AppSize.minTouchTarget, child: clearButton),
      ],
    );
  }

  String get _dateLabel {
    if (startDate == null || endDate == null) return 'Seleccionar rango';
    final formatter = DateFormat('dd/MM/yy');
    return '${formatter.format(startDate!)} – ${formatter.format(endDate!)}';
  }
}

class _ThemedSvgIcon extends StatelessWidget {
  const _ThemedSvgIcon({required this.assetName});

  final String assetName;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: SvgPicture.asset(
        '$assetImgIcon$assetName',
        width: AppSize.iconM,
        colorFilter: ColorFilter.mode(
          Theme.of(context).primaryColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
