// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tipo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TipoModel _$TipoModelFromJson(Map<String, dynamic> json) => _TipoModel(
  id: (json['id'] as num?)?.toInt(),
  codigo: json['codigo'] as String?,
  nombre: json['nombre'] as String?,
);

Map<String, dynamic> _$TipoModelToJson(_TipoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'codigo': instance.codigo,
      'nombre': instance.nombre,
    };
