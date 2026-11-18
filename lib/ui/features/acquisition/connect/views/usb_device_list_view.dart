import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/navigation/route_args/multi_mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/connect/view_models/acquisition_connect_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class UsbDeviceListRoute extends StatelessWidget {
  const UsbDeviceListRoute({
    required this.requisitionId,
    required this.sessionId,
    this.destination = AcquisitionDestination.mirror,
    super.key,
  });
  final String requisitionId;
  final String sessionId;
  final AcquisitionDestination destination;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => AcquisitionConnectViewModel(
      repository: context.read<AcquisitionRepository>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
      destination: destination,
    )..initialize(),
    child: const UsbDeviceListView(),
  );
}

class UsbDeviceListView extends StatelessWidget {
  const UsbDeviceListView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AcquisitionConnectViewModel>();
    final session = viewModel.navigationSession;
    final multiSession = viewModel.navigationMultiSession;
    final transferConnection = viewModel.transferConnection;
    if (transferConnection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted || viewModel.transferConnection == null) return;
        viewModel.markNavigationHandled();
        context.pushReplacementNamed(
          AppRouteName.fileTransfer,
          pathParameters: {
            'requisitionId': transferConnection.requisitionId,
            'sessionId': transferConnection.sessionId,
          },
        );
      });
    }
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted ||
            viewModel.navigationSession?.textureId != session.textureId)
          return;
        viewModel.markNavigationHandled();
        await context.pushNamed(
          AppRouteName.mirror,
          pathParameters: {
            'requisitionId': session.requisitionId,
            'sessionId': session.sessionId,
          },
          extra: MirrorRouteArgs(
            textureId: session.textureId,
            controlLocalId: session.controlStreamId,
            videoSize: Size(
              session.videoWidth.toDouble(),
              session.videoHeight.toDouble(),
            ),
            deviceName: session.deviceName,
          ),
        );
        if (context.mounted) await viewModel.refresh();
      });
    }
    if (multiSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted || viewModel.navigationMultiSession == null)
          return;
        viewModel.markNavigationHandled();
        await context.pushNamed(
          AppRouteName.multiMirror,
          pathParameters: {
            'requisitionId': multiSession.requisitionId,
            'sessionId': multiSession.sessionId,
          },
          extra: MultiMirrorRouteArgs(
            sources: multiSession.sources
                .map(
                  (source) => MultiMirrorSourceArgs(
                    sourceSessionId: source.sourceSessionId,
                    textureId: source.textureId,
                    videoSize: Size(
                      source.videoWidth.toDouble(),
                      source.videoHeight.toDouble(),
                    ),
                    deviceName: source.deviceName,
                  ),
                )
                .toList(growable: false),
          ),
        );
        if (context.mounted) await viewModel.refresh();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.destination == AcquisitionDestination.transfer
              ? 'Conectar para transferir archivos'
              : viewModel.isMultiMirror
              ? 'Conectar mirrors Android'
              : 'Conectar dispositivo objetivo',
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: viewModel.isBusy ? null : viewModel.refresh,
            tooltip: 'Volver a enumerar USB',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: constraints.maxHeight < 480 ? AppSpace.s : AppSpace.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionHeader(viewModel: viewModel),
                  const SizedBox(height: AppSpace.l),
                  Text(
                    'Dispositivos disponibles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    viewModel.destination == AcquisitionDestination.transfer
                        ? 'Conecta el cable OTG y autoriza ADB para explorar el almacenamiento compartido.'
                        : viewModel.isMultiMirror
                        ? 'Selecciona uno o varios objetivos ADB conectados al hub USB y luego inicia sus mirrors.'
                        : 'Conecta el cable OTG, activa la depuración USB y acepta la huella RSA en el equipo objetivo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.m),
                  _UsbTopologySummary(viewModel: viewModel),
                  const SizedBox(height: AppSpace.m),
                  _DeviceContent(viewModel: viewModel),
                  if (viewModel.isMultiMirror &&
                      viewModel.adbDeviceCount > 0) ...[
                    const SizedBox(height: AppSpace.s),
                    Text(
                      '${viewModel.adbDeviceCount} objetivo${viewModel.adbDeviceCount == 1 ? '' : 's'} ADB detectado${viewModel.adbDeviceCount == 1 ? '' : 's'} · '
                      '${viewModel.selectedDeviceIds.length} seleccionado${viewModel.selectedDeviceIds.length == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.m),
                    FilledButton.icon(
                      onPressed:
                          viewModel.selectedDeviceIds.isEmpty ||
                              viewModel.isBusy
                          ? null
                          : viewModel.connectSelected,
                      icon: const Icon(Icons.grid_view_rounded),
                      label: Text(
                        'Iniciar ${viewModel.selectedDeviceIds.length} mirror${viewModel.selectedDeviceIds.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                  if (viewModel.message != null) ...[
                    const SizedBox(height: AppSpace.m),
                    _StatusMessage(viewModel: viewModel),
                  ],
                  if (viewModel.hasDiagnostics) ...[
                    const SizedBox(height: AppSpace.m),
                    _ConnectionDiagnosticsCard(viewModel: viewModel),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.viewModel});
  final AcquisitionConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.m),
    decoration: _cardDecoration(context),
    child: Row(
      children: [
        const Icon(Icons.shield_outlined),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requisa ${viewModel.requisitionId}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Sesión ${viewModel.sessionId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const _StatusChip(label: 'En curso'),
      ],
    ),
  );
}

class _DeviceContent extends StatelessWidget {
  const _DeviceContent({required this.viewModel});
  final AcquisitionConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.phase == AcquisitionConnectionPhase.loading)
      return const Center(child: CircularProgressIndicator());
    if (viewModel.availability == AcquisitionAvailability.unsupported) {
      return const _EmptyDeviceCard(
        icon: Icons.usb_off_outlined,
        title: 'Captura USB no disponible',
      );
    }
    if (viewModel.devices.isEmpty) {
      return _EmptyDeviceCard(
        icon: Icons.usb_off_outlined,
        title: 'No se detectaron dispositivos',
        description:
            'Android no enumeró ningún periférico USB. Confirma que el '
            'conector principal del hub esté en el inspector, que el puerto '
            'USB-A sea de datos y, si tu equipo lo ofrece, activa OTG o selecciona '
            '“USB controlado por: Este dispositivo”.',
        action: TextButton.icon(
          onPressed: viewModel.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Buscar nuevamente'),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: viewModel.devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        final device = viewModel.devices[index];
        final selected = viewModel.isMultiMirror
            ? viewModel.selectedDeviceIds.contains(device.id)
            : viewModel.selectedDeviceId == device.id;
        return _DeviceCard(
          device: device,
          busy: selected && viewModel.isBusy,
          selected: selected,
          authorized: viewModel.authorizedDeviceIds.contains(device.id),
          multiSelection: viewModel.isMultiMirror,
          onTap: () => viewModel.selectDevice(device),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.busy,
    required this.selected,
    required this.authorized,
    required this.multiSelection,
    required this.onTap,
  });
  final AcquisitionDevice device;
  final bool busy;
  final bool selected;
  final bool authorized;
  final bool multiSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final deviceColor = device.supportsAdb ? colors.primary : colors.tertiary;
    final selectionColor = multiSelection && !selected
        ? colors.outline
        : deviceColor;
    final icon = switch (device.deviceType) {
      'hub' => Icons.hub_outlined,
      'mtp' => Icons.folder_open_outlined,
      'hid' => Icons.keyboard_outlined,
      'video' => Icons.videocam_outlined,
      _ => Icons.usb_outlined,
    };
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              Container(
                width: AppSize.minTouchTarget,
                height: AppSize.minTouchTarget,
                decoration: BoxDecoration(
                  color: deviceColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                child: Icon(
                  device.supportsAdb ? Icons.phone_android : icon,
                  color: deviceColor,
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'VID ${device.vendorId.toRadixString(16).toUpperCase()} · PID ${device.productId.toRadixString(16).toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      device.shortSerial.isEmpty
                          ? device.connectionLabel
                          : '${device.connectionLabel} · ID ${device.shortSerial}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      device.supportsAdb
                          ? authorized
                                ? 'ADB autorizado · identidad RSA confirmada'
                                : 'ADB disponible${device.hasPermission ? ' · permiso USB concedido' : ' · requiere permiso USB'}'
                          : _usbTypeDescription(device.deviceType),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: deviceColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: AppSize.iconL,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  multiSelection
                      ? selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked
                      : authorized
                      ? Icons.check_circle
                      : !device.supportsAdb
                      ? Icons.info_outline
                      : device.hasPermission
                      ? Icons.arrow_forward
                      : Icons.lock_open,
                  color: selectionColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.viewModel});
  final AcquisitionConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isError = viewModel.phase == AcquisitionConnectionPhase.error;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.sync, color: color),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(viewModel.message!)),
          if (isError)
            TextButton(
              onPressed: viewModel.retry,
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}

class _ConnectionDiagnosticsCard extends StatelessWidget {
  const _ConnectionDiagnosticsCard({required this.viewModel});

  final AcquisitionConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.m),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, color: Colors.white70, size: 18),
            const SizedBox(width: AppSpace.xs),
            const Expanded(
              child: Text(
                'Diagnóstico de conexión ADB',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: viewModel.diagnosticLog),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnóstico copiado.')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        const Text(
          'Si vuelve a fallar, copia este bloque completo y envíalo para revisar el punto exacto del handshake.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: AppSpace.s),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: SelectableText(
              viewModel.diagnosticLog,
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
  );
}

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard({
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.xl),
    decoration: _cardDecoration(context),
    child: Column(
      children: [
        Icon(icon, size: 40),
        const SizedBox(height: AppSpace.s),
        Text(title, textAlign: TextAlign.center),
        if (description != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (action != null) action!,
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(AppRadius.l),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 7)),
  ],
);

class _UsbTopologySummary extends StatelessWidget {
  const _UsbTopologySummary({required this.viewModel});

  final AcquisitionConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasUsb = viewModel.usbDeviceCount > 0;
    final hasAdb = viewModel.adbDeviceCount > 0;
    final color = hasAdb
        ? colors.primary
        : hasUsb
        ? colors.tertiary
        : colors.outline;
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          Icon(
            hasAdb ? Icons.usb_rounded : Icons.usb_off_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              '${viewModel.usbDeviceCount} periférico${viewModel.usbDeviceCount == 1 ? '' : 's'} USB enumerado${viewModel.usbDeviceCount == 1 ? '' : 's'} · '
              '${viewModel.adbDeviceCount} con ADB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _usbTypeDescription(String type) => switch (type) {
  'mtp' => 'MTP disponible, pero ADB no está expuesto',
  'hub' => 'Hub USB enumerado; esperando objetivos ADB',
  'hid' => 'Periférico de entrada HID, no es un objetivo ADB',
  'video' => 'Capturadora de video UVC, no es un objetivo ADB',
  _ => 'Periférico USB sin interfaz ADB',
};
