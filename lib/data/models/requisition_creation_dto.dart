import 'package:file_cast/domain/models/requisition_creation.dart';

final class EcosystemCaseDto {
  const EcosystemCaseDto({
    required this.id,
    required this.cud,
    required this.type,
    required this.division,
    required this.subjects,
    required this.officials,
  });

  factory EcosystemCaseDto.fromJson(Map<String, dynamic> json) {
    final divisions = _asList(
      json['casoCasosDivisiones'] ?? json['divisions'] ?? json['divisiones'],
    );
    final people = _asList(
      json['suprCasosPersonas'] ?? json['subjects'] ?? json['personas'],
    );
    final officials = _asList(
      json['persCasoFuncionarios'] ?? json['officials'] ?? json['funcionarios'],
    );

    return EcosystemCaseDto(
      id: _asInt(json['id'] ?? json['casoId']),
      cud: _asString(json['cud'] ?? json['codigoCud']) ?? 'Sin CUD',
      type:
          _nestedName(json['casoTipoDenuncia']) ??
          _nestedName(json['tipoDenuncia']) ??
          _asString(json['caseType']) ??
          'Sin tipo',
      division: divisions
          .map(_divisionLabel)
          .where((value) => value.isNotEmpty)
          .join(', ')
          .ifEmpty('Sin division'),
      subjects: people
          .map(_subjectLabel)
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      officials: officials
          .map(_officialLabel)
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  final int id;
  final String cud;
  final String type;
  final String division;
  final List<String> subjects;
  final List<String> officials;

  EcosystemCaseSummary toDomain() {
    return EcosystemCaseSummary(
      id: id,
      cud: cud,
      type: type,
      division: division,
      subjects: subjects,
      officials: officials,
    );
  }

  static String _divisionLabel(Object? value) {
    final map = _asMap(value);
    return _nestedName(map['division']) ??
        _nestedName(map['fiscaliaDivision']) ??
        _nestedName(map['fiscalia']) ??
        _asString(map['nombre']) ??
        _asString(map['name']) ??
        '';
  }

  static String _subjectLabel(Object? value) {
    final map = _asMap(value);
    final person = _asMap(map['suprPersona']);
    final subject = <String, dynamic>{
      ..._asMap(map['person']),
      ..._asMap(map['persona']),
    };
    final alias = _asString(map['alias']);
    final name =
        _asString(person['nombreCompleto']) ??
        _asString(subject['nombreCompleto']) ??
        [
          _asString(person['nombres']),
          _asString(person['primerApellido']),
          _asString(person['segundoApellido']),
          _asString(subject['nombres']),
          _asString(subject['primerApellido']),
          _asString(subject['segundoApellido']),
        ].whereType<String>().join(' ').trim();
    return name.isNotEmpty ? name : alias ?? _asString(map['fullName']) ?? '';
  }

  static String _officialLabel(Object? value) {
    final map = _asMap(value);
    final person = _asMap(map['persona']);
    final funcionario = _asMap(map['funcionario']);
    return _asString(map['nombreCompleto']) ??
        _asString(person['nombreCompleto']) ??
        _asString(funcionario['nombreCompleto']) ??
        _asString(map['fullName']) ??
        _nestedName(map['cargo']) ??
        '';
  }
}

final class PersonSummaryDto {
  const PersonSummaryDto({
    required this.id,
    required this.name,
    required this.ci,
    this.birthDate,
    this.address,
    this.phone,
  });

  factory PersonSummaryDto.fromJson(Map<String, dynamic> json) {
    return PersonSummaryDto(
      id: _asInt(json['id'] ?? json['personaId'] ?? json['segipPersonaId']),
      name:
          _asString(json['nombreCompleto']) ??
          _asString(json['fullName']) ??
          _joinName(json) ??
          'Sin nombre',
      ci:
          _asString(json['ci']) ??
          _asString(json['numeroDocumento']) ??
          _asString(json['documentNumber']) ??
          'Sin CI',
      birthDate: DateTime.tryParse(
        _asString(json['fechaNacimiento'] ?? json['birthDate']) ?? '',
      ),
      address:
          _asString(json['domicilioDireccion']) ??
          _asString(json['segipDireccion']) ??
          _asString(json['address']),
      phone:
          _asString(json['celular']) ??
          _asString(json['domicilioTelefono']) ??
          _asString(json['domicilioCelular']) ??
          _asString(json['phone']),
    );
  }

  final int id;
  final String name;
  final String ci;
  final DateTime? birthDate;
  final String? address;
  final String? phone;

  PersonSummary toDomain() {
    return PersonSummary(
      id: id,
      name: name,
      ci: ci,
      birthDate: birthDate,
      address: address,
      phone: phone,
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

List<Object?> _asList(Object? value) {
  return value is List ? value : const [];
}

Map<String, dynamic> _asMap(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

String? _nestedName(Object? value) {
  if (value is String) return _asString(value);
  final map = _asMap(value);
  return _asString(map['nombre']) ??
      _asString(map['descripcion']) ??
      _asString(map['name']) ??
      _asString(map['label']);
}

String? _joinName(Map<String, dynamic> json) {
  final value = [
    _asString(json['nombres']),
    _asString(json['primerApellido']),
    _asString(json['segundoApellido']),
  ].whereType<String>().join(' ').trim();
  return value.isEmpty ? null : value;
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
