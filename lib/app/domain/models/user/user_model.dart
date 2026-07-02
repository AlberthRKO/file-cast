import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  factory UserModel({
    int? id,
    String? usuario,
    String? nombreCompleto,
    int? dobleAutenticacion,
    int? estado,
    List<String?>? roles,
    List<String?>? permisos,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
