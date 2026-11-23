import 'dart:async';
import 'dart:math' as math;

import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/remote_request_exception.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/data/services/requisition_service.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';

class OfflineFirstRequisitionRepository implements RequisitionRepository {
  OfflineFirstRequisitionRepository({
    required RequisitionService remote,
    required RequisitionDetailService detailService,
    required LocalEvidenceDatabaseService local,
    required ConnectivityRepository connectivity,
  }) : _remote = remote,
       _detailService = detailService,
       _local = local,
       _connectivity = connectivity;

  final RequisitionService _remote;
  final RequisitionDetailService _detailService;
  final LocalEvidenceDatabaseService _local;
  final ConnectivityRepository _connectivity;
  final Map<String, Future<void>> _catalogWarmups = {};
  final Map<String, Future<void>> _detailWarmups = {};

  @override
  Future<RequisitionPage> getRequisitions({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  }) async {
    await _refreshConnectivityIfUnknown();
    if (_worksOffline) {
      return _cachedPage(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );
    }
    try {
      final accountId = await _local.currentAccountId();
      final remote = await _remote.list(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );
      try {
        final records = remote.items
            .map((item) => _toCacheRecord(item, remote))
            .toList(growable: false);
        final isCompleteCatalog =
            page == 1 &&
            (search == null || search.trim().isEmpty) &&
            status == null &&
            remote.pageCount <= 1;
        if (isCompleteCatalog) {
          await _local.replaceRequisitionCatalog(
            records: records,
            accountId: accountId,
          );
          _scheduleDetailSnapshots(
            accountId: accountId,
            requisitionIds: records.map((record) => record.id),
          );
        } else {
          await _local.saveRequisitionPage(
            records: records,
            accountId: accountId,
          );
          if (page == 1 &&
              (search == null || search.trim().isEmpty) &&
              status == null &&
              remote.pageCount > 1) {
            _scheduleCompleteCatalog(
              accountId: accountId,
              firstPage: remote,
              limit: limit,
            );
          }
        }
      } on Object {
        // La respuesta remota sigue siendo válida aunque el cache local esté
        // temporalmente ocupado por el worker de sincronización.
      }
      return remote;
    } on RemoteRequestException catch (remoteError) {
      if (!remoteError.allowsOfflineFallback) rethrow;
      return _cachedPage(
        page: page,
        limit: limit,
        search: search,
        status: status,
        remoteError: remoteError,
      );
    }
  }

  void _scheduleCompleteCatalog({
    required String accountId,
    required RequisitionPage firstPage,
    required int limit,
  }) {
    if (_catalogWarmups.containsKey(accountId)) return;
    final operation = _completeCatalog(
      accountId: accountId,
      firstPage: firstPage,
      limit: limit,
    );
    _catalogWarmups[accountId] = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_catalogWarmups[accountId], operation)) {
          _catalogWarmups.remove(accountId);
        }
      }),
    );
  }

  Future<void> _completeCatalog({
    required String accountId,
    required RequisitionPage firstPage,
    required int limit,
  }) async {
    try {
      final records = <String, LocalRequisitionCacheRecord>{
        for (final item in firstPage.items)
          item.id: _toCacheRecord(item, firstPage),
      };
      var pageCount = firstPage.pageCount;
      for (var page = 2; page <= pageCount; page++) {
        if (_worksOffline || await _local.currentAccountId() != accountId) {
          return;
        }
        final remotePage = await _remote.list(
          page: page,
          limit: limit,
        );
        pageCount = math.max(pageCount, remotePage.pageCount);
        for (final item in remotePage.items) {
          records[item.id] = _toCacheRecord(item, remotePage);
        }
      }
      await _local.replaceRequisitionCatalog(
        records: records.values.toList(growable: false),
        accountId: accountId,
      );
      _scheduleDetailSnapshots(
        accountId: accountId,
        requisitionIds: records.keys,
      );
    } on Object {
      // La primera página ya quedó persistida. Una falla durante el calentado
      // conserva el cache anterior y se reintentará en una apertura posterior.
    }
  }

  void _scheduleDetailSnapshots({
    required String accountId,
    required Iterable<String> requisitionIds,
  }) {
    if (_detailWarmups.containsKey(accountId)) return;
    final ids = requisitionIds.toSet().toList(growable: false);
    final operation = _warmMissingDetailSnapshots(
      accountId: accountId,
      requisitionIds: ids,
    );
    _detailWarmups[accountId] = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_detailWarmups[accountId], operation)) {
          _detailWarmups.remove(accountId);
        }
      }),
    );
  }

  Future<void> _warmMissingDetailSnapshots({
    required String accountId,
    required List<String> requisitionIds,
  }) async {
    try {
      final cachedIds = await _local.cachedDetailRequisitionIds(
        accountId: accountId,
      );
      for (final requisitionId in requisitionIds) {
        if (cachedIds.contains(requisitionId)) continue;
        if (_worksOffline || await _local.currentAccountId() != accountId) {
          return;
        }
        try {
          final snapshot = await _detailService.getDetailSnapshot(
            requisitionId,
          );
          await _local.saveRequisitionDetailSnapshot(
            requisitionId: requisitionId,
            payloadJson: snapshot.payloadJson,
            accountId: accountId,
          );
        } on Object {
          // Una requisa con fallo no impide preparar las demás; al abrirla en
          // línea se intentará nuevamente mediante el repositorio de detalle.
        }
      }
    } on Object {
      // El cache existente sigue siendo válido y se reintentará más adelante.
    }
  }

  LocalRequisitionCacheRecord _toCacheRecord(
    Requisition item,
    RequisitionPage page,
  ) {
    final location = page.locations[item.id];
    return LocalRequisitionCacheRecord(
      id: item.id,
      caseName: item.caseName,
      registeredAt: item.registeredAt,
      status: item.status.name,
      imageCount: item.imageEvidenceCount,
      videoCount: item.videoEvidenceCount,
      isSynchronized: item.isSynchronized,
      cud: item.cud,
      subjectName: item.subjectName,
      latitude: location?.latitude,
      longitude: location?.longitude,
      locationLabel: location?.label,
      documentCount: page.documentEvidenceCounts[item.id] ?? 0,
    );
  }

  Future<RequisitionPage> _cachedPage({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
    Object? remoteError,
  }) async {
    final cached = await _local.cachedRequisitions();
    if (cached.isEmpty) {
      if (remoteError != null) throw remoteError;
      throw StateError(
        'No hay requisas guardadas para trabajar sin conexión. '
        'Conéctate una vez para preparar el catálogo offline.',
      );
    }
    return _localPage(
      cached,
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
  }

  bool get _worksOffline => switch (_connectivity.currentStatus) {
    ConnectivityStatus.offline || ConnectivityStatus.limited => true,
    ConnectivityStatus.checking || ConnectivityStatus.online => false,
  };

  Future<void> _refreshConnectivityIfUnknown() async {
    if (_connectivity.currentStatus != ConnectivityStatus.checking) return;
    await _connectivity.refresh();
  }

  RequisitionPage _localPage(
    List<LocalRequisitionCacheRecord> cached, {
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  }) {
    final normalizedSearch = search?.trim().toLowerCase() ?? '';
    final filtered = cached
        .where((record) {
          final matchesStatus = status == null || record.status == status.name;
          final matchesSearch =
              normalizedSearch.isEmpty ||
              record.caseName.toLowerCase().contains(normalizedSearch) ||
              (record.cud?.toLowerCase().contains(normalizedSearch) ?? false) ||
              (record.subjectName?.toLowerCase().contains(normalizedSearch) ??
                  false);
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
    final safeLimit = math.max(1, limit);
    final pageCount = filtered.isEmpty
        ? 0
        : (filtered.length / safeLimit).ceil();
    final safePage = math.max(1, page);
    final start = (safePage - 1) * safeLimit;
    final pageRecords = start >= filtered.length
        ? const <LocalRequisitionCacheRecord>[]
        : filtered.sublist(start, math.min(start + safeLimit, filtered.length));
    final items = pageRecords.map(_toDomain).toList(growable: false);
    return (
      items: items,
      page: safePage,
      pageCount: pageCount,
      locations: {
        for (final record in pageRecords)
          if (record.latitude != null && record.longitude != null)
            record.id: RequisitionLocation(
              latitude: record.latitude!,
              longitude: record.longitude!,
              label: record.locationLabel,
            ),
      },
      documentEvidenceCounts: {
        for (final record in pageRecords) record.id: record.documentCount,
      },
    );
  }

  Requisition _toDomain(LocalRequisitionCacheRecord record) => Requisition(
    id: record.id,
    caseName: record.caseName,
    registeredAt: record.registeredAt,
    status: RequisitionStatus.values.firstWhere(
      (value) => value.name == record.status,
      orElse: () => RequisitionStatus.draft,
    ),
    imageEvidenceCount: record.imageCount,
    videoEvidenceCount: record.videoCount,
    isSynchronized: record.isSynchronized,
    cud: record.cud,
    subjectName: record.subjectName,
  );

  @override
  Future<String> createAcquisitionSession({
    required String requisitionId,
    required String sourcePlatform,
    required String transport,
  }) async {
    final session = await _local.ensureLocalAcquisitionSession(
      requisitionId: requisitionId,
      sourcePlatform: sourcePlatform,
      transport: transport,
    );
    return session.localId;
  }

  @override
  Future<RequisitionParticipantUser> searchParticipantUserByCi(String ci) =>
      _remote.searchParticipantUserByCi(ci);

  @override
  Future<void> addParticipant({
    required String requisitionId,
    required String ci,
    required RequisitionParticipantRole role,
  }) => _remote.addParticipant(
    requisitionId: requisitionId,
    ci: ci,
    role: role,
  );

  @override
  Future<void> changeParticipantRole({
    required String requisitionId,
    required String actorId,
    required RequisitionParticipantRole role,
  }) => _remote.changeParticipantRole(
    requisitionId: requisitionId,
    actorId: actorId,
    role: role,
  );

  @override
  Future<void> linkCase({
    required String requisitionId,
    required int? externalCaseId,
    required String cud,
    required String type,
    required String division,
    required List<String> subjects,
    required List<String> participants,
  }) => _remote.linkCase(
    requisitionId: requisitionId,
    externalCaseId: externalCaseId,
    cud: cud,
    type: type,
    division: division,
    subjects: subjects,
    participants: participants,
  );

  @override
  Future<void> finalizeRequisition(String requisitionId) =>
      _remote.finalizeRequisition(requisitionId);
}
