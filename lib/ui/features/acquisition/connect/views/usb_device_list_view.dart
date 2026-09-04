import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/navigation/route_args/mirror_route_args.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/acquisition/connect/view_models/acquisition_connect_view_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class UsbDeviceListRoute extends StatelessWidget {
  const UsbDeviceListRoute({
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });
  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => AcquisitionConnectViewModel(
      repository: context.read<AcquisitionRepository>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
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
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted ||
            viewModel.navigationSession?.textureId != session.textureId)
          return;
        viewModel.markNavigationHandled();
        context.pushNamed(
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
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar dispositivo objetivo'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    'Conecta el cable OTG, activa la depuración USB y acepta la huella RSA en el equipo objetivo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.m),
                  _DeviceContent(viewModel: viewModel),
                  if (viewModel.message != null) ...[
                    const SizedBox(height: AppSpace.m),
                    _StatusMessage(viewModel: viewModel),
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
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        final device = viewModel.devices[index];
        final selected = viewModel.selectedDeviceId == device.id;
        return _DeviceCard(
          device: device,
          busy: selected && viewModel.isBusy,
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
    required this.onTap,
  });
  final AcquisitionDevice device;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                child: Icon(Icons.phone_android, color: colors.primary),
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
                  device.hasPermission ? Icons.arrow_forward : Icons.lock_open,
                  color: colors.primary,
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

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard({
    required this.icon,
    required this.title,
    this.action,
  });
  final IconData icon;
  final String title;
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
