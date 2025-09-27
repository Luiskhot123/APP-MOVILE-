import 'package:flutter_riverpod/flutter_riverpod.dart';

class SesionState {
  final int idEmpresa;
  final String usuario;
  final String rol; // Ej: "INVENTARIO", "FACTURACION", "INVENTARIO-FACTURACION", "ADMIN"

  // 🔹 Datos de la empresa
  final String nombreEmpresa;
  final String nit;
  final String direccion;

  // 🔹 Datos DIAN (dummy por ahora)
  final String resolucionDian;
  final String claveTecnica;
  final String tipoAmbiente; // "PRUEBAS" o "PRODUCCION"

  const SesionState({
    required this.idEmpresa,
    required this.usuario,
    required this.rol,
    required this.nombreEmpresa,
    required this.nit,
    required this.direccion,
    this.resolucionDian = '0000000000',  // 🔹 Dummy
    this.claveTecnica = 'CLAVE_DUMMY',   // 🔹 Dummy
    this.tipoAmbiente = 'PRUEBAS',               // 🔹 Dummy: 2 = pruebas
  });


  bool hasRole(String r) {
    if (rol == 'ADMIN') return true;
    return rol.split('-').contains(r);
  }

  bool get isAdmin => rol == 'ADMIN';

  // 🔹 Copia el estado con cambios
  SesionState copyWith({
    int? idEmpresa,
    String? usuario,
    String? rol,
    String? nombreEmpresa,
    String? nit,
    String? direccion,
    String? resolucionDian,
    String? claveTecnica,
    String? tipoAmbiente,
  }) {
    return SesionState(
      idEmpresa: idEmpresa ?? this.idEmpresa,
      usuario: usuario ?? this.usuario,
      rol: rol ?? this.rol,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      nit: nit ?? this.nit,
      direccion: direccion ?? this.direccion,
      resolucionDian: resolucionDian ?? this.resolucionDian,
      claveTecnica: claveTecnica ?? this.claveTecnica,
      tipoAmbiente: tipoAmbiente ?? this.tipoAmbiente,
    );
  }

}

/// Provider global de sesión (null = no hay sesión iniciada)
final sesionProvider = StateProvider<SesionState?>((ref) => null);
