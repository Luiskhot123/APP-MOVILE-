import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sesion_provider.dart';

class RoleGuard extends ConsumerWidget {
  final Widget page;
  final String requiredRole; // "INVENTARIO" o "FACTURACION"

  const RoleGuard({super.key, required this.page, required this.requiredRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);

    if (sesion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesión requerida')),
        body: Center(
          child: Text('No hay sesión activa. Ve al login.'),
        ),
      );
    }

    if (sesion.isAdmin) return page;
    if (sesion.hasRole(requiredRole)) return page;

    // acceso denegado
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso denegado')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No tienes permisos para ver esta página.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
