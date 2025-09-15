import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/correo_facturacion_modal.dart';
import '../pages/generar_codigo_page.dart';
import '../providers/sesion_provider.dart';
import '../pages/dashboard_page.dart';
import '../main.dart'; // Home (si la tienes aquí)

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final isAdmin = sesion?.isAdmin ?? false;
    final canInventario = isAdmin || (sesion?.hasRole('INVENTARIO') ?? false);
    final canFacturacion = isAdmin || (sesion?.hasRole('FACTURACION') ?? false);
    final usuario = sesion?.usuario ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Text(
              "Menú - $usuario",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          if (canInventario && canFacturacion && isAdmin) ListTile(
            title: const Text("Mi Empresa"),
            onTap: () => Navigator.pushReplacementNamed(context,'/dashboard'),
          ),
          if (canInventario && canFacturacion && isAdmin) ListTile(
            title: const Text("Inventario y Facturación"),
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          if (isAdmin && sesion?.idEmpresa != null) ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("Generar código de vinculación"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GenerarCodigoPage(idEmpresa: sesion!.idEmpresa)),
              );
            },
          ),
          if (isAdmin && sesion?.idEmpresa != null) ListTile(
            leading: const Icon(Icons.email),
            title: Row(
              children: [
                const Text("Correo facturación"),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const InfoCorreoFacturacionModal(),
                    );
                  },
                  child: const Icon(Icons.help_outline, size: 18, color: Colors.grey),
                ),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const CorreoFacturacionModal(),
              );
            },
          ),




          if (canInventario && !canFacturacion) ListTile(
            title: const Text("Inventario"),
            onTap: () => Navigator.pushReplacementNamed(context, '/inventory'),
          ),
          if (canFacturacion && !canInventario) ListTile(
            title: const Text("Facturación"),
            onTap: () => Navigator.pushReplacementNamed(context, '/facturas'),
          ),
          if (canInventario && canFacturacion && !isAdmin) ...[
            // usuario con ambos roles pero no admin -> dar acceso a tabs igual al 'home'
            ListTile(
              title: const Text("Inventario y Facturación"),
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
          ],

        ],
      ),
    );
  }
}