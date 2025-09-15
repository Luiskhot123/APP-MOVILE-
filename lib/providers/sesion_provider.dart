import 'package:flutter_riverpod/flutter_riverpod.dart';

class SesionState {
  final int idEmpresa;
  final String usuario;
  final String rol; // Ej: "INVENTARIO", "FACTURACION", "INVENTARIO-FACTURACION", "ADMIN"

  const SesionState({
    required this.idEmpresa,
    required this.usuario,
    required this.rol,
  });

  bool hasRole(String r) {
    if (rol == 'ADMIN') return true;
    return rol.split('-').contains(r);
  }

  bool get isAdmin => rol == 'ADMIN';
}

/// Provider global de sesión (null = no hay sesión iniciada)
final sesionProvider = StateProvider<SesionState?>((ref) => null);
