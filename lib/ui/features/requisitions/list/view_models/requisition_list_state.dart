import 'package:file_cast/domain/models/requisition.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'requisition_list_state.freezed.dart';

enum RequisitionListPhase { initial, loading, content, empty, error }

@freezed
abstract class RequisitionListState with _$RequisitionListState {
  const factory RequisitionListState({
    @Default(RequisitionListPhase.initial) RequisitionListPhase phase,
    @Default(<Requisition>[]) List<Requisition> items,
    @Default(<Requisition>[]) List<Requisition> filteredItems,
    @Default('') String query,
    RequisitionStatus? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    @Default(0) int page,
    @Default(7) int pageSize,
    @Default(false) bool isRefreshing,
    String? errorMessage,
  }) = _RequisitionListState;
}
