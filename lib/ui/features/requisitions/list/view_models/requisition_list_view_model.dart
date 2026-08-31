import 'dart:math' as math;

import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/ui/features/requisitions/list/view_models/requisition_list_state.dart';
import 'package:flutter/foundation.dart';

class RequisitionListViewModel extends ChangeNotifier {
  RequisitionListViewModel({
    required RequisitionRepository repository,
  }) : _repository = repository;

  final RequisitionRepository _repository;

  RequisitionListState _state = const RequisitionListState();
  RequisitionListState get state => _state;

  List<Requisition> get visibleItems {
    if (_state.filteredItems.isEmpty) return const [];
    final end = math.min(
      (_state.page + 1) * _state.pageSize,
      _state.filteredItems.length,
    );
    return _state.filteredItems.sublist(0, end);
  }

  bool get hasMore => visibleItems.length < _state.filteredItems.length;

  Future<void> load() async {
    if (_state.phase == RequisitionListPhase.loading) return;
    _emit(
      _state.copyWith(
        phase: RequisitionListPhase.loading,
        errorMessage: null,
      ),
    );

    try {
      final items = await _repository.getRequisitions();
      _state = _state.copyWith(items: items);
      _applyFilters(resetPage: true);
    } catch (_) {
      _emit(
        _state.copyWith(
          phase: RequisitionListPhase.error,
          errorMessage: 'No se pudo cargar el listado de requisas.',
        ),
      );
    }
  }

  Future<void> refresh() async {
    if (_state.isRefreshing) return;
    _emit(_state.copyWith(isRefreshing: true, errorMessage: null));

    try {
      final items = await _repository.getRequisitions();
      _state = _state.copyWith(items: items, isRefreshing: false);
      _applyFilters(resetPage: false);
    } catch (_) {
      _emit(
        _state.copyWith(
          isRefreshing: false,
          errorMessage: 'No se pudo actualizar el listado.',
        ),
      );
    }
  }

  void updateQuery(String value) {
    _state = _state.copyWith(query: value);
    _applyFilters(resetPage: true);
  }

  void updateStatus(RequisitionStatus? value) {
    _state = _state.copyWith(statusFilter: value);
    _applyFilters(resetPage: true);
  }

  void updateDateRange({DateTime? start, DateTime? end}) {
    _state = _state.copyWith(startDate: start, endDate: end);
    _applyFilters(resetPage: true);
  }

  void clearFilters() {
    _state = _state.copyWith(
      query: '',
      statusFilter: null,
      startDate: null,
      endDate: null,
    );
    _applyFilters(resetPage: true);
  }

  void loadMore() {
    if (!hasMore || _state.phase != RequisitionListPhase.content) return;
    _emit(_state.copyWith(page: _state.page + 1));
  }

  void _applyFilters({required bool resetPage}) {
    final normalizedQuery = _state.query.trim().toLowerCase();
    final endExclusive = _state.endDate == null
        ? null
        : DateTime(
            _state.endDate!.year,
            _state.endDate!.month,
            _state.endDate!.day + 1,
          );

    final filtered = _state.items.where((item) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.id.toLowerCase().contains(normalizedQuery) ||
          (item.cud?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (item.subjectName?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          item.caseName.toLowerCase().contains(normalizedQuery);
      final matchesStatus =
          _state.statusFilter == null || item.status == _state.statusFilter;
      final matchesStart =
          _state.startDate == null ||
          !item.registeredAt.isBefore(_state.startDate!);
      final matchesEnd =
          endExclusive == null || item.registeredAt.isBefore(endExclusive);

      return matchesQuery && matchesStatus && matchesStart && matchesEnd;
    }).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));

    final lastPage = math.max(
      0,
      (filtered.length / _state.pageSize).ceil() - 1,
    );
    final nextPage = resetPage ? 0 : math.min(_state.page, lastPage);

    _emit(
      _state.copyWith(
        filteredItems: filtered,
        page: nextPage,
        phase: filtered.isEmpty
            ? RequisitionListPhase.empty
            : RequisitionListPhase.content,
      ),
    );
  }

  void _emit(RequisitionListState value) {
    _state = value;
    notifyListeners();
  }
}
