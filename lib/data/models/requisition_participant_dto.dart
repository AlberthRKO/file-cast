import 'package:file_cast/domain/models/requisition_detail.dart';

final class RequisitionParticipantUserDto {
  const RequisitionParticipantUserDto({
    required this.id,
    required this.username,
    required this.fullName,
    required this.personId,
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.secondLastName,
    required this.personProfileId,
    this.employeeId,
  });

  factory RequisitionParticipantUserDto.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final personId = _int(json['personaId']);
    final personProfileId = _int(json['perfilPersonaId']);
    if (id == null || personId == null || personProfileId == null) {
      throw const FormatException(
        'El backend no devolvió la identidad completa del usuario.',
      );
    }

    return RequisitionParticipantUserDto(
      id: id,
      username: _text(json['usuario']) ?? '',
      fullName: _text(json['nombreCompleto']) ?? '',
      personId: personId,
      ci: _text(json['ci']) ?? '',
      firstName: _text(json['nombre']) ?? '',
      lastName: _text(json['paterno']) ?? '',
      secondLastName: _text(json['materno']) ?? '',
      personProfileId: personProfileId,
      employeeId: _int(json['funcionarioId']),
    );
  }

  final int id;
  final String username;
  final String fullName;
  final int personId;
  final String ci;
  final String firstName;
  final String lastName;
  final String secondLastName;
  final int personProfileId;
  final int? employeeId;

  RequisitionParticipantUser toDomain() {
    return RequisitionParticipantUser(
      id: id,
      username: username,
      fullName: fullName,
      personId: personId,
      ci: ci,
      firstName: firstName,
      lastName: lastName,
      secondLastName: secondLastName,
      personProfileId: personProfileId,
      employeeId: employeeId,
    );
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(_text(value) ?? '');
  }
}
