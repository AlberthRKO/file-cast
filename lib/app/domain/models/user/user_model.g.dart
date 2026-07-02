// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: (json['id'] as num?)?.toInt(),
  usuario: json['usuario'] as String?,
  nombreCompleto: json['nombreCompleto'] as String?,
  dobleAutenticacion: (json['dobleAutenticacion'] as num?)?.toInt(),
  estado: (json['estado'] as num?)?.toInt(),
  roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String?).toList(),
  permisos: (json['permisos'] as List<dynamic>?)
      ?.map((e) => e as String?)
      .toList(),
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'usuario': instance.usuario,
      'nombreCompleto': instance.nombreCompleto,
      'dobleAutenticacion': instance.dobleAutenticacion,
      'estado': instance.estado,
      'roles': instance.roles,
      'permisos': instance.permisos,
    };
