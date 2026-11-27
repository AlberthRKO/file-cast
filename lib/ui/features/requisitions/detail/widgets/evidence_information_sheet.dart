import 'dart:math' as math;

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EvidenceInformationSheet extends StatelessWidget {
  const EvidenceInformationSheet({
    required this.evidence,
    this.session,
    super.key,
  });

  final RequisitionEvidence evidence;
  final RequisitionAcquisitionSession? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = evidence.metadata ?? const <String, dynamic>{};
    final sourceId = metadata['sourceSessionId'];
    final device =
        session?.sourceDeviceNames[sourceId] ??
        _text(metadata['sourceDeviceName']) ??
        session?.sourceModel ??
        session?.sourceDeviceId;
    final file = <_InfoField>[
      _InfoField('Nombre', evidence.effectiveName, 'file.svg'),
      if (evidence.name != evidence.effectiveName)
        _InfoField('Nombre original', evidence.name, 'file.svg'),
      if ((evidence.plaintextByteLength ?? evidence.byteLength) > 0)
        _InfoField(
          'Tamaño',
          _size(evidence.plaintextByteLength ?? evidence.byteLength),
          'file.svg',
        ),
    ];
    final origin = <_InfoField>[
      if (_text(evidence.acquisitionMethod) != null)
        _InfoField(
          'Método de adquisición',
          _method(evidence.acquisitionMethod!, metadata),
          'sync.svg',
        ),
      if (_text(device) != null)
        _InfoField('Dispositivo objetivo', device!, 'folder.svg'),
      if (_text(metadata['inspectorDeviceName']) case final inspector?)
        _InfoField('Equipo inspector', inspector, 'folder.svg'),
      if (_text(session?.transport) != null && session?.transport != 'UNKNOWN')
        _InfoField('Transporte', _transport(session!.transport), 'sync.svg'),
      if (_text(evidence.sourcePath) != null)
        _InfoField(
          'Ruta o referencia de origen',
          evidence.sourcePath!,
          'folder.svg',
        ),
    ];
    final dates = <_InfoField>[
      _InfoField(
        'Adquirido por App Inspector',
        _date(evidence.createdAt),
        'calendarDay.svg',
      ),
      if (_dateFrom(metadata['recordingStartedAt']) case final started?)
        _InfoField('Inicio de grabación', started, 'calendarDay.svg'),
      if (evidence.sourceCreatedAt case final created?)
        _InfoField(
          metadata['sourceCreatedAtSource'] == 'MTP_DATE_CREATED'
              ? 'Creación del archivo en el dispositivo'
              : 'Creación informada por origen',
          _date(created),
          'calendarDay.svg',
          source: _source(_text(metadata['sourceCreatedAtSource'])),
        ),
      if (_dateFrom(metadata['sourceModifiedAt']) case final modified?)
        _InfoField(
          'Última modificación en origen',
          modified,
          'calendarDay.svg',
        ),
      if (_dateFrom(metadata['registeredOnDeviceAt']) case final registered?)
        _InfoField(
          metadata['registeredOnDeviceAtSource'] ==
                  'INSPECTOR_PHOTOKIT_ADDED_DATE'
              ? 'Añadida a fototeca del inspector'
              : 'Añadida a biblioteca de origen',
          registered,
          'calendarDay.svg',
          source: _source(_text(metadata['registeredOnDeviceAtSource'])),
        ),
      if (_dateFrom(metadata['contentCapturedAt']) case final captured?)
        _InfoField(
          'Captura declarada por origen',
          captured,
          'calendarDay.svg',
          source: _source(_text(metadata['contentCapturedAtSource'])),
        ),
    ];

    return Material(
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.min(720, MediaQuery.sizeOf(context).height * .9),
          ),
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
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icons/file.svg',
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
                            'Información de la evidencia',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            evidence.effectiveName,
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
                      onPressed: () => context.pop(),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = constraints.maxWidth >= 560
                            ? (constraints.maxWidth - AppSpace.s) / 2
                            : constraints.maxWidth;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(context, 'Archivo', file, tileWidth),
                            if (origin.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.m),
                              _section(context, 'Origen', origin, tileWidth),
                            ],
                            if (dates.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.m),
                              _section(context, 'Fechas', dates, tileWidth),
                            ],
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

  Widget _section(
    BuildContext context,
    String title,
    List<_InfoField> fields,
    double width,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpace.s),
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final field in fields) _InfoTile(width: width, field: field),
          ],
        ),
      ],
    );
  }

  String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  String _date(DateTime date) =>
      DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  String? _dateFrom(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    return date == null ? null : _date(date);
  }

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
  String _transport(String value) => switch (value) {
    'SYSTEM_PICKER' => 'Selector de archivos',
    'USB_ADB' || 'ADB' => 'USB · ADB',
    'USB_MTP' || 'MTP' => 'USB · MTP',
    _ => value,
  };
  String _method(String value, Map<String, dynamic> metadata) =>
      switch (value) {
        'SCREEN_CAPTURE' => 'Captura de pantalla',
        'SCREEN_RECORDING' => 'Grabación de pantalla',
        'DEVICE_TRANSFER' => 'Transferencia de dispositivo',
        'IMPORTED_FILE' =>
          metadata['registeredOnDeviceAtSource'] ==
                  'INSPECTOR_PHOTOKIT_ADDED_DATE'
              ? 'Importación de fototeca'
              : 'Importación de archivo',
        _ => value,
      };
  String? _source(String? value) => switch (value) {
    'MTP_DATE_CREATED' => 'Informada por MTP',
    'INSPECTOR_PHOTOKIT_ADDED_DATE' => 'Fototeca del inspector',
    'PH_ASSET_CREATION_DATE' => 'Declarada por PhotoKit',
    _ => value,
  };
}

final class _InfoField {
  const _InfoField(this.label, this.value, this.icon, {this.source});
  final String label;
  final String value;
  final String icon;
  final String? source;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.width, required this.field});
  final double width;
  final _InfoField field;

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
                'assets/images/icons/${field.icon}',
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
                      field.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    SelectableText(
                      field.value,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (field.source != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        field.source!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
