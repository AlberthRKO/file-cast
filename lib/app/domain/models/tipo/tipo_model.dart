import 'package:freezed_annotation/freezed_annotation.dart';

part 'tipo_model.freezed.dart';
part 'tipo_model.g.dart';

@freezed
abstract class TipoModel with _$TipoModel {
  factory TipoModel({
    int? id,
    String? codigo,
    String? nombre,
  }) = _TipoModel;

  factory TipoModel.fromJson(Map<String, dynamic> json) =>
      _$TipoModelFromJson(json);
}
