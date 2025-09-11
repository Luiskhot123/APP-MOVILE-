import 'package:flutter_riverpod/flutter_riverpod.dart';

class SesionState {
  final int idEmpresa;
  final String usuario;

  SesionState({required this.idEmpresa, required this.usuario});
}

/// Provider global de sesión (null = no hay sesión iniciada)
final sesionProvider = StateProvider<SesionState?>((ref) => null);
