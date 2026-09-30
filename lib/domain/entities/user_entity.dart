class UserEntity {
  const UserEntity({
    this.id,
    this.usuario,
    this.numeroDocumento,
    this.nombreCompleto,
    this.dobleAutenticacion,
    this.estado,
    this.roles,
    this.permisos,
  });

  final int? id;
  final String? usuario;
  final String? numeroDocumento;
  final String? nombreCompleto;
  final int? dobleAutenticacion;
  final int? estado;
  final List<String?>? roles;
  final List<String?>? permisos;
}
