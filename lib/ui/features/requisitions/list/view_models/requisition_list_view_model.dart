import 'dart:async';

import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/ui/features/requisitions/list/view_models/requisition_list_state.dart';
import 'package:flutter/foundation.dart';

class RequisitionListViewModel extends ChangeNotifier {
  RequisitionListViewModel({
    required RequisitionRepository repository,
  }) : _repository = repository;

  static const _pageSize = 20;
  static const _queryDebounce = Duration(milliseconds: 350);

  final RequisitionRepository _repository;

  RequisitionListState _state = const RequisitionListState();
  Timer? _queryDebounceTimer;
  bool _isLoadingFirstPage = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _nextPage = 1;
  int _requestSequence = 0;
  bool _reloadWhenReady = false;
  String? _loadMoreError;
  String? _finalizingId;

  RequisitionListState get state => _state;
  List<Requisition> get visibleItems => _state.filteredItems;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get loadMoreError => _loadMoreError;
  bool get isFinalizing => _finalizingId != null;

  @override
  void dispose() {
    _queryDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> load() => _loadFirstPage();

  Future<void> refresh() => _loadFirstPage(showRefreshing: true);

  void updateQuery(String value) {
    _state = _state.copyWith(query: value);
    _hasMore = false;
    _loadMoreError = null;
    notifyListeners();
    _queryDebounceTimer?.cancel();
    _queryDebounceTimer = Timer(_queryDebounce, () {
      unawaited(_loadFirstPage());
    });
  }

  void updateStatus(RequisitionStatus? value) {
    _state = _state.copyWith(statusFilter: value);
    _queryDebounceTimer?.cancel();
    notifyListeners();
    unawaited(_loadFirstPage());
  }

  void updateDateRange({DateTime? start, DateTime? end}) {
    _state = _state.copyWith(startDate: start, endDate: end);
    _queryDebounceTimer?.cancel();
    _hasMore = false;
    _loadMoreError = null;
    _applyDateFilter();
    unawaited(_loadFirstPage());
  }

  void clearFilters() {
    _queryDebounceTimer?.cancel();
    _state = _state.copyWith(
      query: '',
      statusFilter: null,
      startDate: null,
      endDate: null,
    );
    _hasMore = false;
    _loadMoreError = null;
    notifyListeners();
    unawaited(_loadFirstPage());
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoadingFirstPage) return;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final page = await _repository.getRequisitions(
        page: _nextPage,
        limit: _pageSize,
        search: _state.query,
        status: _state.statusFilter,
      );
      final merged = _mergeUnique(_state.items, page.items);
      _nextPage = page.page + 1;
      _hasMore = page.page < page.pageCount;
      final filtered = _filterByDate(merged);
      _state = _state.copyWith(
        items: List<Requisition>.unmodifiable(merged),
        filteredItems: filtered,
        page: page.page,
        pageSize: _pageSize,
        phase: filtered.isEmpty && !_hasMore
            ? RequisitionListPhase.empty
            : RequisitionListPhase.content,
        errorMessage: null,
      );
    } catch (_) {
      _loadMoreError = 'No se pudo cargar más requisas.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
      if (_reloadWhenReady && !_isLoadingFirstPage) {
        _reloadWhenReady = false;
        unawaited(_loadFirstPage());
      }
    }
  }

  Future<String?> finalizeRequisition(String requisitionId) async {
    if (_finalizingId != null) return 'Ya se está finalizando una requisa.';

    _finalizingId = requisitionId;
    notifyListeners();
    try {
      await _repository.finalizeRequisition(requisitionId);
      await _loadFirstPage();
      return null;
    } catch (error) {
      return _messageFromError(error);
    } finally {
      _finalizingId = null;
      notifyListeners();
    }
  }

  Future<void> _loadFirstPage({bool showRefreshing = false}) async {
    if (_isLoadingFirstPage || _isLoadingMore) {
      _reloadWhenReady = true;
      return;
    }

    _isLoadingFirstPage = true;
    final requestId = ++_requestSequence;
    _nextPage = 1;
    _hasMore = false;
    _loadMoreError = null;

    final keepContent = showRefreshing && _state.items.isNotEmpty;
    _state = _state.copyWith(
      phase: keepContent
          ? RequisitionListPhase.content
          : RequisitionListPhase.loading,
      isRefreshing: showRefreshing,
      errorMessage: null,
      page: 0,
      pageSize: _pageSize,
    );
    notifyListeners();

    try {
      final page = await _repository.getRequisitions(
        page: 1,
        limit: _pageSize,
        search: _state.query,
        status: _state.statusFilter,
      );
      if (requestId != _requestSequence) return;

      final filtered = _filterByDate(page.items);
      _nextPage = page.page + 1;
      _hasMore = page.page < page.pageCount;
      _state = _state.copyWith(
        items: List<Requisition>.unmodifiable(page.items),
        filteredItems: filtered,
        page: page.page,
        pageSize: _pageSize,
        phase: filtered.isEmpty && !_hasMore
            ? RequisitionListPhase.empty
            : RequisitionListPhase.content,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (_) {
      if (requestId != _requestSequence) return;
      _state = _state.copyWith(
        phase: keepContent
            ? RequisitionListPhase.content
            : RequisitionListPhase.error,
        isRefreshing: false,
        errorMessage: keepContent
            ? 'No se pudo actualizar el listado.'
            : 'No se pudo cargar el listado de requisas.',
      );
    } finally {
      if (requestId == _requestSequence) {
        _isLoadingFirstPage = false;
        notifyListeners();
        if (_reloadWhenReady) {
          _reloadWhenReady = false;
          unawaited(_loadFirstPage());
        }
      }
    }
  }

  void _applyDateFilter() {
    final filtered = _filterByDate(_state.items);
    _state = _state.copyWith(
      filteredItems: filtered,
      phase: filtered.isEmpty && !_hasMore
          ? RequisitionListPhase.empty
          : RequisitionListPhase.content,
    );
    notifyListeners();
  }

  List<Requisition> _filterByDate(Iterable<Requisition> items) {
    final endExclusive = _state.endDate == null
        ? null
        : DateTime(
            _state.endDate!.year,
            _state.endDate!.month,
            _state.endDate!.day + 1,
          );

    return List<Requisition>.unmodifiable(
      items.where((item) {
        final matchesStart =
            _state.startDate == null ||
            !item.registeredAt.isBefore(_state.startDate!);
        final matchesEnd =
            endExclusive == null || item.registeredAt.isBefore(endExclusive);
        return matchesStart && matchesEnd;
      }),
    );
  }

  List<Requisition> _mergeUnique(
    Iterable<Requisition> current,
    Iterable<Requisition> incoming,
  ) {
    final byId = <String, Requisition>{
      for (final item in current) item.id: item,
    };
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  String _messageFromError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    return message.isEmpty ? 'No se pudo finalizar la requisa.' : message;
  }
}
