// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'requisition_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RequisitionListState {

 RequisitionListPhase get phase; List<Requisition> get items; List<Requisition> get filteredItems; String get query; RequisitionStatus? get statusFilter; DateTime? get startDate; DateTime? get endDate; int get page; int get pageSize; bool get isRefreshing; String? get errorMessage;
/// Create a copy of RequisitionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequisitionListStateCopyWith<RequisitionListState> get copyWith => _$RequisitionListStateCopyWithImpl<RequisitionListState>(this as RequisitionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequisitionListState&&(identical(other.phase, phase) || other.phase == phase)&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.filteredItems, filteredItems)&&(identical(other.query, query) || other.query == query)&&(identical(other.statusFilter, statusFilter) || other.statusFilter == statusFilter)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,phase,const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(filteredItems),query,statusFilter,startDate,endDate,page,pageSize,isRefreshing,errorMessage);

@override
String toString() {
  return 'RequisitionListState(phase: $phase, items: $items, filteredItems: $filteredItems, query: $query, statusFilter: $statusFilter, startDate: $startDate, endDate: $endDate, page: $page, pageSize: $pageSize, isRefreshing: $isRefreshing, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $RequisitionListStateCopyWith<$Res>  {
  factory $RequisitionListStateCopyWith(RequisitionListState value, $Res Function(RequisitionListState) _then) = _$RequisitionListStateCopyWithImpl;
@useResult
$Res call({
 RequisitionListPhase phase, List<Requisition> items, List<Requisition> filteredItems, String query, RequisitionStatus? statusFilter, DateTime? startDate, DateTime? endDate, int page, int pageSize, bool isRefreshing, String? errorMessage
});




}
/// @nodoc
class _$RequisitionListStateCopyWithImpl<$Res>
    implements $RequisitionListStateCopyWith<$Res> {
  _$RequisitionListStateCopyWithImpl(this._self, this._then);

  final RequisitionListState _self;
  final $Res Function(RequisitionListState) _then;

/// Create a copy of RequisitionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? items = null,Object? filteredItems = null,Object? query = null,Object? statusFilter = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? page = null,Object? pageSize = null,Object? isRefreshing = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as RequisitionListPhase,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Requisition>,filteredItems: null == filteredItems ? _self.filteredItems : filteredItems // ignore: cast_nullable_to_non_nullable
as List<Requisition>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,statusFilter: freezed == statusFilter ? _self.statusFilter : statusFilter // ignore: cast_nullable_to_non_nullable
as RequisitionStatus?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RequisitionListState].
extension RequisitionListStatePatterns on RequisitionListState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RequisitionListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RequisitionListState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RequisitionListState value)  $default,){
final _that = this;
switch (_that) {
case _RequisitionListState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RequisitionListState value)?  $default,){
final _that = this;
switch (_that) {
case _RequisitionListState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RequisitionListPhase phase,  List<Requisition> items,  List<Requisition> filteredItems,  String query,  RequisitionStatus? statusFilter,  DateTime? startDate,  DateTime? endDate,  int page,  int pageSize,  bool isRefreshing,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RequisitionListState() when $default != null:
return $default(_that.phase,_that.items,_that.filteredItems,_that.query,_that.statusFilter,_that.startDate,_that.endDate,_that.page,_that.pageSize,_that.isRefreshing,_that.errorMessage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RequisitionListPhase phase,  List<Requisition> items,  List<Requisition> filteredItems,  String query,  RequisitionStatus? statusFilter,  DateTime? startDate,  DateTime? endDate,  int page,  int pageSize,  bool isRefreshing,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _RequisitionListState():
return $default(_that.phase,_that.items,_that.filteredItems,_that.query,_that.statusFilter,_that.startDate,_that.endDate,_that.page,_that.pageSize,_that.isRefreshing,_that.errorMessage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RequisitionListPhase phase,  List<Requisition> items,  List<Requisition> filteredItems,  String query,  RequisitionStatus? statusFilter,  DateTime? startDate,  DateTime? endDate,  int page,  int pageSize,  bool isRefreshing,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _RequisitionListState() when $default != null:
return $default(_that.phase,_that.items,_that.filteredItems,_that.query,_that.statusFilter,_that.startDate,_that.endDate,_that.page,_that.pageSize,_that.isRefreshing,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _RequisitionListState implements RequisitionListState {
  const _RequisitionListState({this.phase = RequisitionListPhase.initial, final  List<Requisition> items = const <Requisition>[], final  List<Requisition> filteredItems = const <Requisition>[], this.query = '', this.statusFilter, this.startDate, this.endDate, this.page = 0, this.pageSize = 7, this.isRefreshing = false, this.errorMessage}): _items = items,_filteredItems = filteredItems;
  

@override@JsonKey() final  RequisitionListPhase phase;
 final  List<Requisition> _items;
@override@JsonKey() List<Requisition> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  List<Requisition> _filteredItems;
@override@JsonKey() List<Requisition> get filteredItems {
  if (_filteredItems is EqualUnmodifiableListView) return _filteredItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_filteredItems);
}

@override@JsonKey() final  String query;
@override final  RequisitionStatus? statusFilter;
@override final  DateTime? startDate;
@override final  DateTime? endDate;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;
@override@JsonKey() final  bool isRefreshing;
@override final  String? errorMessage;

/// Create a copy of RequisitionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequisitionListStateCopyWith<_RequisitionListState> get copyWith => __$RequisitionListStateCopyWithImpl<_RequisitionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequisitionListState&&(identical(other.phase, phase) || other.phase == phase)&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._filteredItems, _filteredItems)&&(identical(other.query, query) || other.query == query)&&(identical(other.statusFilter, statusFilter) || other.statusFilter == statusFilter)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,phase,const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_filteredItems),query,statusFilter,startDate,endDate,page,pageSize,isRefreshing,errorMessage);

@override
String toString() {
  return 'RequisitionListState(phase: $phase, items: $items, filteredItems: $filteredItems, query: $query, statusFilter: $statusFilter, startDate: $startDate, endDate: $endDate, page: $page, pageSize: $pageSize, isRefreshing: $isRefreshing, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$RequisitionListStateCopyWith<$Res> implements $RequisitionListStateCopyWith<$Res> {
  factory _$RequisitionListStateCopyWith(_RequisitionListState value, $Res Function(_RequisitionListState) _then) = __$RequisitionListStateCopyWithImpl;
@override @useResult
$Res call({
 RequisitionListPhase phase, List<Requisition> items, List<Requisition> filteredItems, String query, RequisitionStatus? statusFilter, DateTime? startDate, DateTime? endDate, int page, int pageSize, bool isRefreshing, String? errorMessage
});




}
/// @nodoc
class __$RequisitionListStateCopyWithImpl<$Res>
    implements _$RequisitionListStateCopyWith<$Res> {
  __$RequisitionListStateCopyWithImpl(this._self, this._then);

  final _RequisitionListState _self;
  final $Res Function(_RequisitionListState) _then;

/// Create a copy of RequisitionListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? items = null,Object? filteredItems = null,Object? query = null,Object? statusFilter = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? page = null,Object? pageSize = null,Object? isRefreshing = null,Object? errorMessage = freezed,}) {
  return _then(_RequisitionListState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as RequisitionListPhase,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Requisition>,filteredItems: null == filteredItems ? _self._filteredItems : filteredItems // ignore: cast_nullable_to_non_nullable
as List<Requisition>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,statusFilter: freezed == statusFilter ? _self.statusFilter : statusFilter // ignore: cast_nullable_to_non_nullable
as RequisitionStatus?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
