import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/adaptive/window_size_class.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_card_surface.dart';
import 'package:file_cast/ui/features/acquisition/transfer/view_models/file_transfer_view_model.dart';
import 'package:file_cast/ui/features/acquisition/transfer/widgets/file_transfer_widgets.dart';
import 'package:file_cast/ui/features/acquisition/transfer/widgets/remote_file_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class FileTransferRoute extends StatelessWidget {
  const FileTransferRoute({
    required this.requisitionId,
    required this.sessionId,
    super.key,
  });

  final String requisitionId;
  final String sessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => FileTransferViewModel(
      repository: context.read<AcquisitionRepository>(),
      requisitionId: requisitionId,
      sessionId: sessionId,
    )..initialize(),
    child: const FileTransferView(),
  );
}

class FileTransferView extends StatelessWidget {
  const FileTransferView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FileTransferViewModel>();
    final mediaSize = MediaQuery.sizeOf(context);
    final showSupportingPane =
        mediaSize.width >= 960 && mediaSize.height >= 560;
    final connected =
        viewModel.phase != FileBrowserPhase.disconnected &&
        viewModel.connection != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferencia de archivos'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: connected && !showSupportingPane
          ? TransferBottomBar(viewModel: viewModel)
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final window = AppWindowSize.fromConstraints(constraints);
            final useThreePane =
                constraints.maxWidth >= 960 && !window.hasCompactHeight;
            if (viewModel.phase == FileBrowserPhase.loading &&
                viewModel.detail == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.phase == FileBrowserPhase.disconnected) {
              return _DisconnectedContent(viewModel: viewModel);
            }
            return ConstrainedContent(
              padding: EdgeInsets.all(
                window.hasCompactHeight ? AppSpace.s : AppSpace.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TransferSessionHeader(viewModel: viewModel),
                  if (viewModel.message != null) ...[
                    const SizedBox(height: AppSpace.s),
                    TransferMessageCard(
                      message: viewModel.message!,
                      onDismiss: viewModel.dismissMessage,
                    ),
                  ],
                  const SizedBox(height: AppSpace.m),
                  Expanded(
                    child: useThreePane
                        ? _ExpandedTransferLayout(viewModel: viewModel)
                        : _CompactTransferLayout(viewModel: viewModel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExpandedTransferLayout extends StatelessWidget {
  const _ExpandedTransferLayout({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ubicaciones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.s),
            StorageScopeSelector(
              complete: viewModel.isCompleteStorage,
              enabled:
                  !viewModel.isTransferring && !viewModel.isPreparingPreview,
              onChanged: viewModel.setCompleteStorage,
            ),
            const SizedBox(height: AppSpace.s),
            Expanded(
              child: RemoteLocationList(
                locations: viewModel.visibleLocations,
                onOpen: viewModel.openDirectory,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: AppSpace.m),
      Expanded(child: _BrowserPane(viewModel: viewModel)),
      const SizedBox(width: AppSpace.m),
      SizedBox(
        width: 300,
        child: TransferSelectionPanel(viewModel: viewModel),
      ),
    ],
  );
}

class _CompactTransferLayout extends StatelessWidget {
  const _CompactTransferLayout({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StorageScopeSelector(
        complete: viewModel.isCompleteStorage,
        enabled: !viewModel.isTransferring && !viewModel.isPreparingPreview,
        onChanged: viewModel.setCompleteStorage,
      ),
      const SizedBox(height: AppSpace.s),
      Expanded(child: _BrowserPane(viewModel: viewModel)),
    ],
  );
}

class _BrowserPane extends StatelessWidget {
  const _BrowserPane({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RemoteFileBreadcrumbs(
        items: viewModel.breadcrumbs,
        onTap: viewModel.openPath,
        onRefresh: viewModel.refresh,
      ),
      const SizedBox(height: AppSpace.s),
      Expanded(child: _BrowserContent(viewModel: viewModel)),
    ],
  );
}

class _BrowserContent extends StatelessWidget {
  const _BrowserContent({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.showingLocations) {
      return RemoteLocationList(
        locations: viewModel.visibleLocations,
        onOpen: viewModel.openDirectory,
        grid: true,
      );
    }
    return switch (viewModel.phase) {
      FileBrowserPhase.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      FileBrowserPhase.empty => _StateCard(
        icon: Icons.folder_open_rounded,
        title: 'Esta carpeta está vacía',
        subtitle: 'No hay archivos accesibles mediante ADB en esta ubicación.',
        actionLabel: 'Actualizar',
        onAction: viewModel.refresh,
      ),
      FileBrowserPhase.error => _StateCard(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo abrir la carpeta',
        subtitle: viewModel.message ?? 'Intenta nuevamente.',
        actionLabel: 'Reintentar',
        onAction: viewModel.refresh,
      ),
      FileBrowserPhase.content => RemoteFileList(
        entries: viewModel.entries,
        isSelected: viewModel.isSelected,
        onOpen: viewModel.openDirectory,
        onToggle: viewModel.toggleSelection,
        canPreview: viewModel.canPreview,
        isPreparingPreview: (file) =>
            viewModel.isPreparingPreview &&
            viewModel.previewingFile?.path == file.path,
        onPreview: (file) => _showRemotePreview(context, viewModel, file),
        formatBytes: viewModel.formatBytes,
      ),
      FileBrowserPhase.disconnected => const SizedBox.shrink(),
    };
  }
}

Future<void> _showRemotePreview(
  BuildContext context,
  FileTransferViewModel viewModel,
  RemoteFileEntry file,
) async {
  final preview = await viewModel.preparePreview(file);
  if (preview == null) return;
  if (!context.mounted) {
    await viewModel.closePreview();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder: (_) => RemoteFilePreviewSheet(
      file: file,
      preview: preview,
      sizeLabel: viewModel.formatBytes(file.byteLength),
      selected: viewModel.isSelected(file),
      onToggleSelection: () => viewModel.toggleSelection(file),
    ),
  );
  await viewModel.closePreview();
}

class _DisconnectedContent extends StatelessWidget {
  const _DisconnectedContent({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) => ConstrainedContent(
    maxWidth: AppSize.messageMaxWidth,
    alignment: Alignment.center,
    child: _StateCard(
      icon: Icons.usb_off_rounded,
      title: 'Dispositivo desconectado',
      subtitle:
          viewModel.message ??
          'Conecta el dispositivo objetivo para explorar su almacenamiento compartido.',
      actionLabel: 'Conectar dispositivo',
      onAction: () => context.pushReplacementNamed(
        AppRouteName.acquisitionConnect,
        pathParameters: {
          'requisitionId': viewModel.requisitionId,
          'sessionId': viewModel.sessionId,
        },
        queryParameters: {'destination': 'transfer'},
      ),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.messageMaxWidth),
        child: AppCardSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: scheme.primary),
              const SizedBox(height: AppSpace.s),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.m),
              AppActionButton(
                label: actionLabel,
                onPressed: onAction,
                foregroundColor: brand.onDark,
                gradient: LinearGradient(
                  colors: [
                    brand.actionGradientStart,
                    brand.actionGradientEnd,
                  ],
                ),
                maxWidth: AppSize.actionMaxWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
