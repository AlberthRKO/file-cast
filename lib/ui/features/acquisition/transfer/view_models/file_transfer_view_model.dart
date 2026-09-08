import 'dart:async';

import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:flutter/foundation.dart';

enum FileBrowserPhase { loading, content, empty, disconnected, error }

enum RemoteStorageScope { common, complete }

final class FileBreadcrumb {
  const FileBreadcrumb({required this.label, this.path});

  final String label;
  final String? path;
}

class FileTransferViewModel extends ChangeNotifier {
  FileTransferViewModel({
    required AcquisitionRepository repository,
    required this.requisitionId,
    required this.sessionId,
  }) : _repository = repository;

  static const maxBatchFiles = 200;

  static final commonLocations = <RemoteFileEntry>[
    RemoteFileEntry(
      path: '/sdcard/DCIM',
      name: 'Cámara',
      byteLength: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
      kind: RemoteFileKind.directory,
      isSelectable: false,
    ),
    RemoteFileEntry(
      path: '/sdcard/Pictures',
      name: 'Imágenes',
      byteLength: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
      kind: RemoteFileKind.directory,
      isSelectable: false,
    ),
    RemoteFileEntry(
      path: '/sdcard/Movies',
      name: 'Videos',
      byteLength: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
      kind: RemoteFileKind.directory,
      isSelectable: false,
    ),
    RemoteFileEntry(
      path: '/sdcard/Download',
      name: 'Descargas',
      byteLength: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
      kind: RemoteFileKind.directory,
      isSelectable: false,
    ),
  ];

  static final internalStorageLocation = RemoteFileEntry(
    path: '/sdcard',
    name: 'Almacenamiento interno',
    byteLength: 0,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
    kind: RemoteFileKind.directory,
    isSelectable: false,
  );

  final AcquisitionRepository _repository;
  final String requisitionId;
  final String sessionId;
  StreamSubscription<FileTransferProgress>? _progressSubscription;
  StreamSubscription<void>? _deviceSubscription;
  FileBrowserPhase _phase = FileBrowserPhase.loading;
  RequisitionDetail? _detail;
  AcquisitionConnectionSession? _connection;
  String? _currentPath;
  List<RemoteFileEntry> _entries = const [];
  final Map<String, RemoteFileEntry> _selected = {};
  FileTransferProgress? _progress;
  String? _message;
  bool _isTransferring = false;
  bool _isPreparingPreview = false;
  RemoteFileEntry? _previewingFile;
  RemoteFilePreview? _preview;
  RemoteStorageScope _storageScope = RemoteStorageScope.common;
  bool _disposed = false;

  FileBrowserPhase get phase => _phase;
  RequisitionDetail? get detail => _detail;
  AcquisitionConnectionSession? get connection => _connection;
  String? get currentPath => _currentPath;
  List<RemoteFileEntry> get entries => _entries;
  List<RemoteFileEntry> get selectedFiles =>
      _selected.values.toList(growable: false);
  FileTransferProgress? get progress => _progress;
  String? get message => _message;
  bool get isTransferring => _isTransferring;
  bool get isPreparingPreview => _isPreparingPreview;
  RemoteFileEntry? get previewingFile => _previewingFile;
  RemoteFilePreview? get preview => _preview;
  RemoteStorageScope get storageScope => _storageScope;
  bool get isCompleteStorage => _storageScope == RemoteStorageScope.complete;
  List<RemoteFileEntry> get visibleLocations =>
      isCompleteStorage ? [internalStorageLocation] : commonLocations;
  bool get showingLocations => _currentPath == null;
  int get selectedBytes => _selected.values.fold(
    0,
    (total, file) => total + file.byteLength,
  );

  List<FileBreadcrumb> get breadcrumbs {
    final path = _currentPath;
    if (path == null) return const [FileBreadcrumb(label: 'Ubicaciones')];
    if (isCompleteStorage) {
      return _breadcrumbsFromRoot(internalStorageLocation, path);
    }
    final root = commonLocations.firstWhere(
      (location) =>
          path == location.path || path.startsWith('${location.path}/'),
    );
    return [
      const FileBreadcrumb(label: 'Ubicaciones'),
      ..._breadcrumbsFromRoot(root, path),
    ];
  }

  List<FileBreadcrumb> _breadcrumbsFromRoot(
    RemoteFileEntry root,
    String path,
  ) {
    final relative = path.substring(root.path.length);
    final crumbs = <FileBreadcrumb>[
      FileBreadcrumb(label: root.name, path: root.path),
    ];
    var accumulated = root.path;
    for (final segment
        in relative.split('/').where((part) => part.isNotEmpty)) {
      accumulated = '$accumulated/$segment';
      crumbs.add(FileBreadcrumb(label: segment, path: accumulated));
    }
    return crumbs;
  }

  Future<void> setCompleteStorage(bool enabled) async {
    if (_isTransferring ||
        _isPreparingPreview ||
        enabled == isCompleteStorage) {
      return;
    }
    _storageScope = enabled
        ? RemoteStorageScope.complete
        : RemoteStorageScope.common;
    _currentPath = null;
    _entries = const [];
    _phase = FileBrowserPhase.content;
    _message = null;
    _safeNotify();
    if (enabled) await openPath(internalStorageLocation.path);
  }

  Future<void> initialize() async {
    _progressSubscription = _repository.fileTransferProgress.listen(
      _handleProgress,
    );
    _deviceSubscription = _repository.deviceChanges.listen((_) {
      unawaited(_verifyConnection());
    });
    try {
      _detail = await _repository.getRequisitionDetail(requisitionId);
      _connection = await _repository.activeConnection(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      if (_connection == null) {
        _phase = FileBrowserPhase.disconnected;
        _message =
            'Conecta el dispositivo objetivo para explorar sus archivos.';
      } else {
        _phase = FileBrowserPhase.content;
      }
    } catch (_) {
      _phase = FileBrowserPhase.error;
      _message = 'No se pudo preparar la transferencia de archivos.';
    }
    _safeNotify();
  }

  Future<void> openDirectory(RemoteFileEntry directory) =>
      openPath(directory.path);

  Future<void> openPath(String? path) async {
    if (_isTransferring || _isPreparingPreview) return;
    if (path == null) {
      _currentPath = null;
      _entries = const [];
      _phase = FileBrowserPhase.content;
      _message = null;
      _safeNotify();
      return;
    }
    _phase = FileBrowserPhase.loading;
    _message = null;
    _safeNotify();
    try {
      final entries = await _repository.listRemoteFiles(path);
      _currentPath = path;
      _entries = entries;
      _phase = entries.isEmpty
          ? FileBrowserPhase.empty
          : FileBrowserPhase.content;
    } catch (error) {
      _phase = _isDisconnectedError(error)
          ? FileBrowserPhase.disconnected
          : FileBrowserPhase.error;
      _message = _friendlyError(error);
    }
    _safeNotify();
  }

  Future<void> refresh() => openPath(_currentPath);

  void toggleSelection(RemoteFileEntry file) {
    if (!file.isSelectable || _isTransferring) return;
    if (_selected.containsKey(file.path)) {
      _selected.remove(file.path);
    } else {
      if (_selected.length >= maxBatchFiles) {
        _message = 'Puedes transferir hasta $maxBatchFiles archivos por lote.';
        _safeNotify();
        return;
      }
      _selected[file.path] = file;
    }
    _message = null;
    _safeNotify();
  }

  bool canPreview(RemoteFileEntry file) {
    if (file.isDirectory || !file.isSelectable) return false;
    final extension = file.name.toLowerCase().split('.').last;
    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'bmp',
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      '3gp',
      'mp3',
      'wav',
      'aac',
      'm4a',
      'ogg',
      'oga',
      'opus',
      'flac',
      'amr',
      'pdf',
      'docx',
      'txt',
      'csv',
      'json',
      'xml',
      'log',
    }.contains(extension);
  }

  Future<RemoteFilePreview?> preparePreview(RemoteFileEntry file) async {
    if (!canPreview(file) || _isTransferring || _isPreparingPreview) {
      return null;
    }
    final extension = file.name.toLowerCase().split('.').last;
    final isReadableText = const {
      'txt',
      'csv',
      'json',
      'xml',
      'log',
    }.contains(extension);
    final maxBytes = isReadableText
        ? 10 * 1024 * 1024
        : extension == 'docx'
        ? 25 * 1024 * 1024
        : file.kind == RemoteFileKind.video
        ? 256 * 1024 * 1024
        : file.kind == RemoteFileKind.audio
        ? 128 * 1024 * 1024
        : 64 * 1024 * 1024;
    if (file.byteLength > maxBytes) {
      _message =
          'La vista previa de este formato admite hasta ${formatBytes(maxBytes)}.';
      _safeNotify();
      return null;
    }
    _isPreparingPreview = true;
    _previewingFile = file;
    _preview = null;
    _message = null;
    _safeNotify();
    try {
      _preview = await _repository.prepareRemoteFilePreview(
        requisitionId: requisitionId,
        sessionId: sessionId,
        file: file,
      );
      return _preview;
    } catch (error) {
      _message = _friendlyError(error);
      if (_isDisconnectedError(error)) _phase = FileBrowserPhase.disconnected;
      return null;
    } finally {
      _isPreparingPreview = false;
      _safeNotify();
    }
  }

  Future<void> closePreview() async {
    _preview = null;
    _previewingFile = null;
    _safeNotify();
    try {
      await _repository.discardRemoteFilePreview(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
    } catch (_) {
      // La caché también será reemplazada al preparar el siguiente preview.
    }
  }

  bool isSelected(RemoteFileEntry file) => _selected.containsKey(file.path);

  void clearSelection() {
    if (_isTransferring) return;
    _selected.clear();
    _safeNotify();
  }

  Future<void> transferSelection() async {
    if (_isTransferring || _isPreparingPreview || _selected.isEmpty) return;
    _isTransferring = true;
    _message = null;
    _progress = FileTransferProgress(
      transferId: '',
      phase: FileTransferPhase.preparing,
      fileIndex: 0,
      fileCount: _selected.length,
      fileBytes: 0,
      fileTotalBytes: 0,
      batchBytes: 0,
      batchTotalBytes: selectedBytes,
    );
    _safeNotify();
    try {
      final result = await _repository.transferRemoteFiles(
        requisitionId: requisitionId,
        sessionId: sessionId,
        files: selectedFiles,
      );
      for (final file in result.files) {
        final sourcePath = file.sourcePath;
        if (sourcePath != null) _selected.remove(sourcePath);
      }
      if (result.cancelled) {
        _message =
            'Transferencia cancelada. Los archivos incompletos fueron descartados.';
      } else if (result.failures.isNotEmpty) {
        _message =
            '${result.files.length} archivos transferidos y ${result.failures.length} con error.';
      } else {
        _message = '${result.files.length} archivos guardados en la requisa.';
      }
      _detail = await _repository.getRequisitionDetail(requisitionId);
    } catch (error) {
      _message = _friendlyError(error);
      if (_isDisconnectedError(error)) _phase = FileBrowserPhase.disconnected;
    } finally {
      _isTransferring = false;
      await _verifyConnection();
      _safeNotify();
    }
  }

  Future<void> cancelTransfer() async {
    if (!_isTransferring) return;
    await _repository.cancelFileTransfer();
  }

  void dismissMessage() {
    _message = null;
    _safeNotify();
  }

  void _handleProgress(FileTransferProgress value) {
    if (!_isTransferring) return;
    _progress = value;
    _safeNotify();
  }

  Future<void> _verifyConnection() async {
    final connection = await _repository.activeConnection(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    if (connection == null && !_isTransferring) {
      _connection = null;
      _phase = FileBrowserPhase.disconnected;
      _message = 'El dispositivo objetivo fue desconectado.';
      _safeNotify();
    }
  }

  String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  bool _isDisconnectedError(Object error) {
    final text = error.toString();
    return text.contains('NOT_CONNECTED') || text.contains('Stream closed');
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (_isDisconnectedError(error))
      return 'Se perdió la conexión con el dispositivo objetivo.';
    if (text.contains('TRANSFER_BUSY'))
      return 'Ya existe una transferencia en curso.';
    if (text.contains('espacio suficiente'))
      return 'No hay espacio suficiente para guardar la selección.';
    if (text.contains('límite de 256 MB'))
      return 'El archivo es demasiado grande para la vista previa (máximo 256 MB).';
    if (text.contains('Permission denied'))
      return 'Android no permite leer esta ubicación.';
    return 'No se pudo completar la operación. $text';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      _repository.discardRemoteFilePreview(
        requisitionId: requisitionId,
        sessionId: sessionId,
      ),
    );
    _progressSubscription?.cancel();
    _deviceSubscription?.cancel();
    super.dispose();
  }
}
