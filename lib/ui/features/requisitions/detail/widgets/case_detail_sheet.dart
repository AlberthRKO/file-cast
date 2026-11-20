import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class CaseDetailSheet extends StatelessWidget {
  const CaseDetailSheet({required this.detail, super.key});

  final RequisitionDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caseInfo = detail.caseInfo;
    final crime = caseInfo?.crimes.isNotEmpty == true
        ? caseInfo!.crimes
              .map(
                (item) => [item.name, item.priorityName]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(' · '),
              )
              .join('\n')
        : detail.requisition.caseName;
    final division = [
      caseInfo?.division ?? detail.division,
      caseInfo?.divisionMunicipality,
      caseInfo?.divisionDepartment,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    final factLocation = [
      caseInfo?.factAddress,
      caseInfo?.factZone,
      caseInfo?.factMunicipality,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    return Material(
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.m,
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
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/images/icons/folder.svg',
                        width: AppSize.iconL,
                        height: AppSize.iconL,
                        colorFilter: ColorFilter.mode(
                          theme.colorScheme.onPrimaryContainer,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle del caso',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'CUD ${caseInfo?.cud ?? detail.requisition.cud ?? 'sin registrar'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      constraints: const BoxConstraints.tightFor(
                        width: AppSize.minTouchTarget,
                        height: AppSize.minTouchTarget,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = constraints.maxWidth >= 560
                            ? (constraints.maxWidth - AppSpace.s) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: AppSpace.s,
                          runSpacing: AppSpace.s,
                          children: [
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'estado.svg',
                              label: 'Estado del caso',
                              value: _valueOrFallback(caseInfo?.status),
                            ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'contrato.svg',
                              label: 'Delito',
                              value: _valueOrFallback(crime),
                            ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'file.svg',
                              label: 'Tipo de denuncia',
                              value: _valueOrFallback(caseInfo?.complaintType),
                            ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'marca.svg',
                              label: 'División',
                              value: _valueOrFallback(division),
                            ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'sync.svg',
                              label: 'Etapa',
                              value: _valueOrFallback(caseInfo?.stage),
                            ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'calendarDay.svg',
                              label: 'Fecha del hecho',
                              value: caseInfo?.factAt == null
                                  ? 'Sin fecha registrada'
                                  : DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(caseInfo!.factAt!),
                            ),
                            _CaseDetailTile(
                              width: constraints.maxWidth,
                              icon: 'marca.svg',
                              label: 'Lugar del hecho',
                              value: _valueOrFallback(factLocation),
                            ),
                            if (caseInfo?.story?.trim().isNotEmpty == true)
                              _CaseDetailTile(
                                width: constraints.maxWidth,
                                icon: 'info.svg',
                                label: 'Relato',
                                value: caseInfo!.story!.trim(),
                              ),
                            if (caseInfo?.officials.isNotEmpty == true)
                              _CaseDetailTile(
                                width: constraints.maxWidth,
                                icon: 'users.svg',
                                label: caseInfo!.officials.length == 1
                                    ? 'Funcionario del caso'
                                    : 'Funcionarios del caso',
                                value: caseInfo!.officials
                                    .map(
                                      (official) =>
                                          [
                                                official.fullName,
                                                official.position,
                                                official.divisionName,
                                              ]
                                              .whereType<String>()
                                              .where(
                                                (value) =>
                                                    value.trim().isNotEmpty,
                                              )
                                              .join(' · '),
                                    )
                                    .join('\n'),
                              ),
                            if (detail.description?.trim().isNotEmpty == true)
                              _CaseDetailTile(
                                width: constraints.maxWidth,
                                icon: 'info.svg',
                                label: 'Descripción de la requisa',
                                value: detail.description!.trim(),
                              ),
                            if (detail.procedureAt != null)
                              _CaseDetailTile(
                                width: tileWidth,
                                icon: 'calendarDay.svg',
                                label: 'Fecha del procedimiento',
                                value: DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(detail.procedureAt!),
                              ),
                            _CaseDetailTile(
                              width: tileWidth,
                              icon: 'sync.svg',
                              label: 'Vinculado a la requisa',
                              value: caseInfo == null
                                  ? 'Sin fecha registrada'
                                  : DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(caseInfo.linkedAt),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseDetailTile extends StatelessWidget {
  const _CaseDetailTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/images/icons/$icon',
                width: AppSize.iconM,
                height: AppSize.iconM,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _valueOrFallback(String? value) => value?.trim().isNotEmpty == true
    ? value!.trim()
    : 'Sin información registrada';
