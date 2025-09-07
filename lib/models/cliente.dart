class Cliente {
  final int idCliente;
  final int idTipoDoc;
  final String numeroDocumento;
  final String razonSocial;
  final String nombreCompleto;
  final String direccion;
  final String telefono;
  final String correo;

  Cliente({
    required this.idCliente,
    required this.idTipoDoc,
    required this.numeroDocumento,
    required this.razonSocial,
    required this.nombreCompleto,
    required this.direccion,
    required this.telefono,
    required this.correo,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
    idCliente: map['id_cliente'],
    idTipoDoc: map['id_tipo_doc'],
    numeroDocumento: map['numero_documento'],
    razonSocial: map['razon_social'],
    nombreCompleto: map['nombre_completo'],
    direccion: map['direccion'],
    telefono: map['telefono'],
    correo: map['correo'],
  );
}
