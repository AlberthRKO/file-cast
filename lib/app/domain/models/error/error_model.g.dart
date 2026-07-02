// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ErrorModel _$ErrorModelFromJson(Map<String, dynamic> json) => _ErrorModel(
  error: json['error'],
  message: json['message'] as String?,
  response: json['response'],
  status: (json['status'] as num?)?.toInt(),
);

Map<String, dynamic> _$ErrorModelToJson(_ErrorModel instance) =>
    <String, dynamic>{
      'error': instance.error,
      'message': instance.message,
      'response': instance.response,
      'status': instance.status,
    };
