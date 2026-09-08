import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:file_cast/ui/core/widgets/app_card_surface.dart';
import 'package:file_cast/ui/core/widgets/folder_background.dart';
import 'package:file_cast/ui/features/acquisition/transfer/view_models/file_transfer_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class TransferSessionHeader extends StatelessWidget {
  const TransferSessionHeader({required this.viewModel, super.key});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cud = viewModel.detail?.requisition.cud ?? viewModel.requisitionId;
    return AppCardSurface(
      child: Row(
        children: [
          _IconBox(asset: 'link.svg', color: scheme.primary),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CUD: $cud', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpace.xs),
                Text(
                  viewModel.connection?.deviceName ??
                      'Dispositivo no conectado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s,
              vertical: AppSpace.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'ADB conectado',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StorageScopeSelector extends StatelessWidget {
  const StorageScopeSelector({
    required this.complete,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool complete;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCardSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.storage_rounded : Icons.auto_awesome_rounded,
            size: AppSize.iconM,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exploración completa',
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  complete
                      ? 'Todas las carpetas compartidas accesibles'
                      : 'Cámara, imágenes, videos y descargas',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: complete,
            onChanged: enabled
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class RemoteLocationList extends StatelessWidget {
  const RemoteLocationList({
    required this.locations,
    required this.onOpen,
    super.key,
    this.grid = false,
  });

  final List<RemoteFileEntry> locations;
  final ValueChanged<RemoteFileEntry> onOpen;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    if (!grid) {
      return ListView.separated(
        itemCount: locations.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s),
        itemBuilder: (_, index) => RemoteLocationCard(
          location: locations[index],
          onTap: () => onOpen(locations[index]),
        ),
      );
    }
    return GridView.builder(
      itemCount: locations.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 112,
        crossAxisSpacing: AppSpace.s,
        mainAxisSpacing: AppSpace.s,
      ),
      itemBuilder: (_, index) => RemoteLocationCard(
        location: locations[index],
        onTap: () => onOpen(locations[index]),
      ),
    );
  }
}

class RemoteLocationCard extends StatelessWidget {
  const RemoteLocationCard({
    required this.location,
    required this.onTap,
    super.key,
  });

  final RemoteFileEntry location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    return SizedBox(
      height: 112,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: FolderBackground.panel(
          frontColor: theme.cardColor,
          showDecoration: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.l,
              AppSpace.m,
              AppSpace.m,
            ),
            child: Row(
              children: [
                _IconBox(asset: 'folder.svg', color: brand.folderFront),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        location.path.replaceFirst('/sdcard/', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RemoteFileBreadcrumbs extends StatelessWidget {
  const RemoteFileBreadcrumbs({
    required this.items,
    required this.onTap,
    required this.onRefresh,
    super.key,
  });

  final List<FileBreadcrumb> items;
  final ValueChanged<String?> onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpace.xs),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: AppSize.iconM,
                    ),
                  ),
                TextButton(
                  onPressed: () => onTap(items[index].path),
                  child: Text(items[index].label),
                ),
              ],
            ],
          ),
        ),
      ),
      IconButton(
        onPressed: onRefresh,
        tooltip: 'Actualizar carpeta',
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class RemoteFileList extends StatelessWidget {
  const RemoteFileList({
    required this.entries,
    required this.isSelected,
    required this.onOpen,
    required this.onToggle,
    required this.canPreview,
    required this.isPreparingPreview,
    required this.onPreview,
    required this.formatBytes,
    super.key,
  });

  final List<RemoteFileEntry> entries;
  final bool Function(RemoteFileEntry) isSelected;
  final ValueChanged<RemoteFileEntry> onOpen;
  final ValueChanged<RemoteFileEntry> onToggle;
  final bool Function(RemoteFileEntry) canPreview;
  final bool Function(RemoteFileEntry) isPreparingPreview;
  final ValueChanged<RemoteFileEntry> onPreview;
  final String Function(int) formatBytes;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.only(bottom: AppSpace.xxl),
    itemCount: entries.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s),
    itemBuilder: (_, index) {
      final file = entries[index];
      final previewable = canPreview(file);
      return RemoteFileTile(
        file: file,
        selected: isSelected(file),
        onTap: file.isDirectory
            ? () => onOpen(file)
            : file.isSelectable
            ? () => onToggle(file)
            : null,
        previewable: previewable,
        preparingPreview: isPreparingPreview(file),
        onPreview: previewable ? () => onPreview(file) : null,
        onToggle: file.isSelectable ? () => onToggle(file) : null,
        sizeLabel: formatBytes(file.byteLength),
      );
    },
  );
}

class RemoteFileTile extends StatelessWidget {
  const RemoteFileTile({
    required this.file,
    required this.selected,
    required this.sizeLabel,
    required this.previewable,
    required this.preparingPreview,
    super.key,
    this.onTap,
    this.onToggle,
    this.onPreview,
  });

  final RemoteFileEntry file;
  final bool selected;
  final String sizeLabel;
  final bool previewable;
  final bool preparingPreview;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCardSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      onTap: onTap,
      color: selected ? scheme.primary.withValues(alpha: .12) : theme.cardColor,
      child: Row(
        children: [
          _IconBox(asset: _assetFor(file.kind), color: scheme.primary),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  file.isDirectory
                      ? 'Carpeta'
                      : '$sizeLabel · ${DateFormat('dd/MM/yyyy HH:mm').format(file.modifiedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (file.isDirectory)
            const Icon(Icons.chevron_right_rounded)
          else if (file.isSelectable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (previewable)
                  preparingPreview
                      ? const SizedBox.square(
                          dimension: AppSize.minTouchTarget,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.m),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: onPreview,
                          tooltip: 'Previsualizar',
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle?.call(),
                ),
              ],
            )
          else
            Tooltip(
              message: 'Tipo de archivo no transferible',
              child: Icon(Icons.block, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class TransferSelectionPanel extends StatelessWidget {
  const TransferSelectionPanel({required this.viewModel, super.key});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.selectedFiles;
    return AppCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selección (${selected.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected.isNotEmpty && !viewModel.isTransferring)
                TextButton(
                  onPressed: viewModel.clearSelection,
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          Text(
            viewModel.formatBytes(viewModel.selectedBytes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.m),
          if (selected.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Selecciona archivos para incorporarlos a la requisa.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: selected.length,
                itemBuilder: (_, index) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SvgPicture.asset(
                    'assets/images/icons/${_assetFor(selected[index].kind)}',
                    width: AppSize.iconM,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  title: Text(
                    selected[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: viewModel.isTransferring
                      ? null
                      : IconButton(
                          onPressed: () =>
                              viewModel.toggleSelection(selected[index]),
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          if (viewModel.isTransferring && viewModel.progress != null) ...[
            const SizedBox(height: AppSpace.s),
            TransferProgressCard(
              progress: viewModel.progress!,
              formatBytes: viewModel.formatBytes,
            ),
          ],
          const SizedBox(height: AppSpace.m),
          if (viewModel.isTransferring)
            TextButton.icon(
              onPressed: viewModel.cancelTransfer,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar transferencia'),
            )
          else
            _TransferButton(viewModel: viewModel),
        ],
      ),
    );
  }
}

class TransferBottomBar extends StatelessWidget {
  const TransferBottomBar({required this.viewModel, super.key});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Theme.of(context).cardColor,
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (viewModel.isTransferring && viewModel.progress != null) ...[
                TransferProgressCard(
                  progress: viewModel.progress!,
                  formatBytes: viewModel.formatBytes,
                ),
                const SizedBox(height: AppSpace.s),
              ],
              if (constraints.maxWidth < 520) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${viewModel.selectedFiles.length} archivos · ${viewModel.formatBytes(viewModel.selectedBytes)}',
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                if (viewModel.isTransferring)
                  TextButton(
                    onPressed: viewModel.cancelTransfer,
                    child: const Text('Cancelar transferencia'),
                  )
                else
                  _TransferButton(viewModel: viewModel),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${viewModel.selectedFiles.length} archivos · ${viewModel.formatBytes(viewModel.selectedBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    if (viewModel.isTransferring)
                      TextButton(
                        onPressed: viewModel.cancelTransfer,
                        child: const Text('Cancelar'),
                      )
                    else
                      SizedBox(
                        width: 220,
                        child: _TransferButton(viewModel: viewModel),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TransferProgressCard extends StatelessWidget {
  const TransferProgressCard({
    required this.progress,
    required this.formatBytes,
    super.key,
  });

  final FileTransferProgress progress;
  final String Function(int) formatBytes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        progress.phase == FileTransferPhase.preparing
            ? 'Preparando transferencia…'
            : progress.fileName ?? 'Transfiriendo archivos…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: AppSpace.s),
      LinearProgressIndicator(
        value: progress.batchTotalBytes > 0 ? progress.batchFraction : null,
      ),
      const SizedBox(height: AppSpace.xs),
      Text(
        progress.batchTotalBytes > 0
            ? '${formatBytes(progress.batchBytes)} de ${formatBytes(progress.batchTotalBytes)}'
            : '${progress.fileIndex + 1} de ${progress.fileCount}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class TransferMessageCard extends StatelessWidget {
  const TransferMessageCard({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCardSurface(
      color: scheme.primary.withValues(alpha: .12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Cerrar mensaje',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _TransferButton extends StatelessWidget {
  const _TransferButton({required this.viewModel});

  final FileTransferViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.of(context);
    return AppActionButton(
      label: 'Transferir archivos',
      onPressed: viewModel.selectedFiles.isEmpty || viewModel.isPreparingPreview
          ? null
          : viewModel.transferSelection,
      foregroundColor: brand.onDark,
      gradient: LinearGradient(
        colors: [brand.actionGradientStart, brand.actionGradientEnd],
      ),
      leadingAsset: 'assets/images/icons/download.svg',
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.asset, required this.color});

  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSize.minTouchTarget,
    height: AppSize.minTouchTarget,
    padding: const EdgeInsets.all(AppSpace.s + AppSpace.xs),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    child: SvgPicture.asset(
      'assets/images/icons/$asset',
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

String _assetFor(RemoteFileKind kind) => switch (kind) {
  RemoteFileKind.directory => 'folder.svg',
  RemoteFileKind.image => 'gallery.svg',
  RemoteFileKind.video => 'video.svg',
  RemoteFileKind.audio => 'microphone.svg',
  RemoteFileKind.document => 'file.svg',
  RemoteFileKind.other => 'clip.svg',
};
