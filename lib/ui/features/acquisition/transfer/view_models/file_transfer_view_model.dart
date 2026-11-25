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
  int? _selectedSubjectPersonId;
  String? _deviceKey;
  AcquisitionConnectionSession? _connection;
  String? _currentPath;
  List<RemoteFileEntry> _mtpRoots = const [];
  final List<RemoteFileEntry> _mtpTrail = [];
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
  int? get selectedSubjectPersonId => _selectedSubjectPersonId;
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
  bool get isMtp => _connection?.transport == 'mtp';
  List<RemoteFileEntry> get visibleLocations => isMtp
      ? _mtpRoots
      : isCompleteStorage
      ? [internalStorageLocation]
      : commonLocations;
  bool get showingLocations => _currentPath == null;
  int get selectedBytes => _selected.values.fold(
    0,
    (total, file) => total + file.byteLength,
  );

  List<RequisitionSubjectSummary> get availableSubjects =>
      _detail?.anchorableSubjects ?? const [];

  RequisitionSubjectSummary? get selectedSubject {
    final selectedId = _selectedSubjectPersonId;
    if (selectedId == null) return null;
    for (final subject in availableSubjects) {
      if (subject.personId == selectedId) return subject;
    }
    return null;
  }

  bool get canChangeSubject =>
      availableSubjects.isNotEmpty && !_isTransferring && !_isPreparingPreview;

  void selectSubject(int? personId) {
    if (!canChangeSubject) return;
    if (personId != null &&
        !availableSubjects.any((subject) => subject.personId == personId)) {
      return;
    }
    _selectedSubjectPersonId = personId;
    final deviceKey = _deviceKey;
    if (deviceKey != null) {
      _repository.setSubjectForDevice(
        requisitionId: requisitionId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        personId: personId,
      );
    }
    _safeNotify();
  }

  List<int> get _selectedSubjectIds {
    final personId = selectedSubject?.personId;
    return personId == null ? const [] : [personId];
  }

  List<FileBreadcrumb> get breadcrumbs {
    final path = _currentPath;
    if (path == null) return const [FileBreadcrumb(label: 'Ubicaciones')];
    if (isMtp)
      return [
        const FileBreadcrumb(label: 'Ubicaciones'),
        ..._mtpTrail.map(
          (entry) => FileBreadcrumb(label: entry.name, path: entry.path),
        ),
      ];
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
      final connection = _connection;
      if (connection != null) _restoreSubjectAssociation(connection);
      if (_connection == null) {
        _phase = FileBrowserPhase.disconnected;
        _message =
            'Conecta el dispositivo objetivo para explorar sus archivos.';
      } else {
        _phase = FileBrowserPhase.content;
        if (isMtp) {
          _mtpRoots = await _repository.listRemoteFiles('mtp:/');
        }
      }
    } catch (_) {
      _phase = FileBrowserPhase.error;
      _message = 'No se pudo preparar la transferencia de archivos.';
    }
    _safeNotify();
  }

  Future<void> openDirectory(RemoteFileEntry directory) =>
      _openDirectory(directory);

  Future<void> _openDirectory(RemoteFileEntry directory) async {
    if (isMtp) {
      final existing = _mtpTrail.indexWhere(
        (entry) => entry.path == directory.path,
      );
      if (existing >= 0) {
        _mtpTrail.removeRange(existing + 1, _mtpTrail.length);
      } else {
        _mtpTrail.add(directory);
      }
    }
    await openPath(directory.path);
  }

  Future<void> openPath(String? path) async {
    if (_isTransferring || _isPreparingPreview) return;
    if (path == null) {
      _currentPath = null;
      _mtpTrail.clear();
      _entries = const [];
      _phase = FileBrowserPhase.content;
      _message = null;
      _safeNotify();
      return;
    }
    _phase = FileBrowserPhase.loading;
    if (isMtp && path != _mtpTrail.lastOrNull?.path) {
      final index = _mtpTrail.indexWhere((entry) => entry.path == path);
      if (index >= 0) _mtpTrail.removeRange(index + 1, _mtpTrail.length);
    }
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
      'm4v',
      'ts',
      'mts',
      'm2ts',
      'flv',
      'wmv',
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
      'doc',
      'docx',
      'docm',
      'xls',
      'xlsx',
      'xlsm',
      'ppt',
      'pptx',
      'pptm',
      'rtf',
      'tsv',
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
      'tsv',
      'json',
      'xml',
      'log',
    }.contains(extension);
    final maxBytes = isReadableText
        ? 10 * 1024 * 1024
        : const {
            'doc',
            'docx',
            'docm',
            'xls',
            'xlsx',
            'xlsm',
            'ppt',
            'pptx',
            'pptm',
            'rtf',
          }.contains(extension)
        ? 80 * 1024 * 1024
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
        subjectPersonIds: _selectedSubjectIds,
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
    if (connection != null) {
      _connection = connection;
      _restoreSubjectAssociation(connection);
      return;
    }
    if (connection == null && !_isTransferring) {
      _connection = null;
      _phase = FileBrowserPhase.disconnected;
      _message = 'El dispositivo objetivo fue desconectado.';
      _safeNotify();
    }
  }

  void _restoreSubjectAssociation(AcquisitionConnectionSession connection) {
    final deviceKey = connection.usbDeviceId ?? connection.deviceName;
    _deviceKey = deviceKey;
    final personId = _repository.subjectPersonIdForDevice(
      requisitionId: requisitionId,
      sessionId: sessionId,
      deviceKey: deviceKey,
    );
    if (personId == null ||
        availableSubjects.any((subject) => subject.personId == personId)) {
      _selectedSubjectPersonId = personId;
    } else {
      _repository.setSubjectForDevice(
        requisitionId: requisitionId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        personId: null,
      );
      _selectedSubjectPersonId = null;
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
    if (error is FormatException) return error.message;
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
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
