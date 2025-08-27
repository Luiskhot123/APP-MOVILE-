import 'package:flutter/material.dart';
import 'pages/inventory_page.dart';
import 'pages/crear_producto_page.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const Home(),
      routes: {
        '/crear_producto': (context) => const CrearProductoPage(),
      },
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario App'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inventario'),
              Tab(text: 'Facturas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            InventoryPage(),
            Center(child: Text('Facturas (próximamente)')),
          ],
        ),
      ),
    );
  }
}

