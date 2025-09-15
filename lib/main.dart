import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_app/providers/sesion_provider.dart';
import 'package:inventario_app/widgets/app_drawer.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart'; // 👈 nuevo dashboard
import 'pages/inventory_page.dart';
import 'pages/facturas_page.dart';
import 'pages/crear_producto_page.dart';
import 'pages/cargar_factura_page.dart';
import 'pages/crear_cliente_page.dart';
import 'pages/vender_page.dart';
import 'widgets/role_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: dotenv.env['APP_NAME'] ?? 'Inventario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: {
        '/home': (_) => const Home(),
        '/dashboard': (_) => const DashboardPage(),
        '/inventory': (ctx) => const RoleGuard(page: InventoryStandalone(), requiredRole: 'INVENTARIO'),
        '/facturas': (ctx) => const RoleGuard(page: FacturasStandalone(), requiredRole: 'FACTURACION'),
        '/crear_producto': (_) => const CrearProductoPage(),
        '/cargar_factura': (_) => const CargarFacturaPage(),
        '/venta': (_) => const VenderPage(),
        '/crear-cliente': (_) => const CrearClientePage(),
      },
    );
  }
}

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int _index = 0; // 0 = Inventario, 1 = Facturas

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);

    if (sesion == null) {
      // por seguridad, pedir login
      return Scaffold(
        body: Center(child: Text('No hay sesión activa.')),
      );
    }

    final isAdmin = sesion.isAdmin;
    final hasInventario = sesion.hasRole('INVENTARIO');
    final hasFacturacion = sesion.hasRole('FACTURACION');

    // si no es admin y tiene un solo permiso -> mostrar esa pantalla independiente
    if (!isAdmin && hasInventario && !hasFacturacion) {
      return Scaffold(
        appBar: AppBar(title: Text('Inventario - ${sesion.usuario}')),
        drawer: const AppDrawer(),
        body: const InventoryPage(),
      );
    }

    if (!isAdmin && hasFacturacion && !hasInventario) {
      return Scaffold(
        appBar: AppBar(title: Text('Facturas - ${sesion.usuario}')),
        drawer: const AppDrawer(),
        body: const FacturasPage(),
      );
    }

    // Si es admin, o tiene ambos permisos, mostramos la versión con tabs
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventario App"),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () => setState(() => _index = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Inventario",
                      style: TextStyle(
                        fontWeight: _index == 0 ? FontWeight.bold : FontWeight.normal,
                        color: _index == 0 ? Colors.blue : Colors.black,
                      ),
                    ),
                    if (_index == 0)
                      Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 60, color: Colors.blue),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _index = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Facturas",
                      style: TextStyle(
                        fontWeight: _index == 1 ? FontWeight.bold : FontWeight.normal,
                        color: _index == 1 ? Colors.blue : Colors.black,
                      ),
                    ),
                    if (_index == 1)
                      Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 60, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: _index == 0 ? const InventoryPage() : const FacturasPage(),
    );
  }
}

