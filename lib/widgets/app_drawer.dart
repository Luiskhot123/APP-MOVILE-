import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sesion_provider.dart';
import '../pages/dashboard_page.dart';
import '../main.dart'; // Home (si la tienes aquí)

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
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
          ListTile(
            title: const Text("Dashboard"),
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
            },
          ),
          ListTile(
            title: const Text("Inventario y Facturación"),
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home())); // si Home ya no requiere idEmpresa, pásalo sin arg
            },
          ),
          ListTile(
            title: const Text("Ventas"),
            onTap: () {
              Navigator.pushNamed(context, '/venta');
            },
          ),
        ],
      ),
    );
  }
}
