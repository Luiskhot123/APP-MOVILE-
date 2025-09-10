import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../data/usuario_repository.dart';

class DashboardPage extends StatefulWidget {
  final int idEmpresa; // 👈 empresa seleccionada en el login

  const DashboardPage({super.key, required this.idEmpresa});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _productRepo = ProductRepository();
  final _usuarioRepo = UsuarioRepository();

  Map<String, int>? _statsProductos;
  Map<String, int>? _statsMaterias;
  List<Map<String, dynamic>> _usuarios = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print("📌 Entrando a DashboardPage con idEmpresa=${widget.idEmpresa}");
    _cargarDatos();

  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    try {
      final productosStats = await _productRepo.obtenerEstadisticas();
      final usuarios = await _usuarioRepo.fetchUsuariosPorEmpresa(widget.idEmpresa);

      // ⚠️ Temporal: materias primas vacías hasta definir tabla
      final materiasStats = {
        "Registradas": 0,
        "En inventario": 0,
        "Bajo stock": 0,
        "Agotadas": 0,
      };

      setState(() {
        _statsProductos = productosStats;
        _statsMaterias = materiasStats;
        _usuarios = usuarios;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Menú de navegación",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              title: const Text("Inventario"),
              onTap: () {
                Navigator.pushNamed(context, '/crear_producto');
              },
            ),
            ListTile(
              title: const Text("Facturas"),
              onTap: () {
                Navigator.pushNamed(context, '/facturas');
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
      ),
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🟦 Mensaje de bienvenida
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "BIENVENIDO A FACTURE\nASÍ ESTÁ COMPUESTA TU EMPRESA ACTUALMENTE",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // 🟦 Equipo de trabajo
              const Text("Tu equipo de trabajo en la App",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _usuarios.length,
                  itemBuilder: (context, index) {
                    final user = _usuarios[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person,
                                  size: 30, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("${user['nombre_completo']}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text(user['usuario'] ?? '',
                                      style:
                                      const TextStyle(color: Colors.grey)),
                                  Text("Rol: ${user['rol'] ?? 'N/A'}",
                                      style:
                                      const TextStyle(color: Colors.blue)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // 🟦 Inventario
              const Text("Tu inventario",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              _buildTable("Producto Final", [
                ["Registrados", "${_statsProductos?['Registrados'] ?? 0}"],
                ["En inventario", "${_statsProductos?['En inventario'] ?? 0}"],
                ["Bajo stock", "${_statsProductos?['Bajo stock'] ?? 0}"],
                ["Agotados", "${_statsProductos?['Agotados'] ?? 0}"],
              ]),
              const SizedBox(height: 12),
              _buildTable("Materias Primas", [
                ["Registradas", "${_statsMaterias?['Registradas'] ?? 0}"],
                ["En inventario", "${_statsMaterias?['En inventario'] ?? 0}"],
                ["Bajo stock", "${_statsMaterias?['Bajo stock'] ?? 0}"],
                ["Agotadas", "${_statsMaterias?['Agotadas'] ?? 0}"],
              ]),
              const SizedBox(height: 16),
              const Divider(),

              // 🟦 Facturas
              const Text("Tus Facturas",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              _buildTable("Facturas Compras", [
                ["Hoy", ""],
                ["Esta semana", ""],
                ["Este mes", ""],
              ]),
              const SizedBox(height: 12),
              _buildTable("Facturas Ventas", [
                ["Hoy", ""],
                ["Esta semana", ""],
                ["Este mes", ""],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Función auxiliar para tablas
  Widget _buildTable(String title, List<List<String>> rows) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: rows
                  .map((r) => TableRow(children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(r[0]),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(r[1],
                      textAlign: TextAlign.center,
                      style:
                      const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
