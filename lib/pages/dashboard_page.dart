import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repository.dart';
import '../data/usuario_repository.dart';
import '../data/facturas_repository.dart';
import '../providers/sesion_provider.dart';
import '../widgets/app_drawer.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _productRepo = ProductRepository();
  final _usuarioRepo = UsuarioRepository();
  final _facturasRepo = FacturasRepository();

  Map<String, int>? _statsProductos;
  Map<String, int>? _statsMaterias;
  Map<String, int>? _statsCompras;
  Map<String, int>? _statsVentas;
  List<Map<String, dynamic>> _usuarios = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    try {
      final sesion = ref.read(sesionProvider);
      if (sesion == null) {
        // no sesión -> volver al login (por seguridad)
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
      final idEmpresa = sesion.idEmpresa;

      final productosStats = await _productRepo.obtenerEstadisticas();
      final usuarios = await _usuarioRepo.fetchUsuariosPorEmpresa(idEmpresa);

      final materiasStats = {
        "Registradas": 0,
        "En inventario": 0,
        "Bajo stock": 0,
        "Agotadas": 0,
      };

      final compras = await _facturasRepo.obtenerEstadisticas("COMPRA");
      final ventas = await _facturasRepo.obtenerEstadisticas("VENTA");

      setState(() {
        _statsProductos = productosStats;
        _statsMaterias = materiasStats;
        _statsCompras = compras;
        _statsVentas = ventas;
        _usuarios = usuarios;
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando datos en Dashboard: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text("Dashboard - ${sesion?.usuario ?? ''}"),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "BIENVENIDO A FACTURE\nASÍ ESTÁ COMPUESTA TU EMPRESA ACTUALMENTE",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text("Tu equipo de trabajo en la App", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person, size: 30, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "${user['nombre_completo'] ?? ''}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                          "Usuario: ${user['usuario'] ?? ''}",
                                          style: const TextStyle(color: Colors.grey)),
                                      Text(
                                        "Contraseña: ${user['contrasena'] ?? ''}",
                                        style: const TextStyle(color: Colors.redAccent),
                                      ),
                                      Text("Rol: ${user['rol'] ?? 'N/A'}",
                                          style: const TextStyle(color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.settings, size: 20),
                                onPressed: () {
                                  _abrirEditarUsuario(user);
                                },
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
              const Text("Tu inventario", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              const Text("Tus Facturas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTable("Facturas Compras", [
                ["Hoy", "${_statsCompras?['Hoy'] ?? 0}"],
                ["Esta semana", "${_statsCompras?['Esta semana'] ?? 0}"],
                ["Este mes", "${_statsCompras?['Este mes'] ?? 0}"],
              ]),
              const SizedBox(height: 12),
              _buildTable("Facturas Ventas", [
                ["Hoy", "${_statsVentas?['Hoy'] ?? 0}"],
                ["Esta semana", "${_statsVentas?['Esta semana'] ?? 0}"],
                ["Este mes", "${_statsVentas?['Este mes'] ?? 0}"],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(String title, List<List<String>> rows) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: rows.map((r) => TableRow(children: [
              Padding(padding: const EdgeInsets.all(6), child: Text(r[0])),
              Padding(padding: const EdgeInsets.all(6), child: Text(r[1], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
            ])).toList(),
          ),
        ]),
      ),
    );
  }
  void _abrirEditarUsuario(Map<String, dynamic> user) {
    final TextEditingController nombreCtrl =
    TextEditingController(text: user['nombre_completo']);
    final TextEditingController usuarioCtrl =
    TextEditingController(text: user['usuario']);
    final TextEditingController contrasenaCtrl =
    TextEditingController(text: user['contrasena']);

    // Roles seleccionados
    bool inventario = user['rol']?.contains("INVENTARIO") ?? false;
    bool facturacion = user['rol']?.contains("FACTURACION") ?? false;
    bool admin = user['rol'] == "ADMIN";

    showDialog(
      context: context,
      builder: (context) {
        // variables locales mutables
        bool inventario = user['rol']?.contains("INVENTARIO") ?? false;
        bool facturacion = user['rol']?.contains("FACTURACION") ?? false;
        bool admin = user['rol'] == "ADMIN";

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Editar Usuario"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: "Nombre completo"),
                    ),
                    TextField(
                      controller: usuarioCtrl,
                      decoration: const InputDecoration(labelText: "Usuario"),
                    ),
                    TextField(
                      controller: contrasenaCtrl,
                      decoration: const InputDecoration(labelText: "Contraseña"),
                      obscureText: false,
                    ),
                    const SizedBox(height: 12),
                    const Text("Rol", style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      value: inventario,
                      title: const Text("Inventario"),
                      onChanged: admin
                          ? null
                          : (v) => setStateDialog(() => inventario = v ?? false),
                    ),
                    CheckboxListTile(
                      value: facturacion,
                      title: const Text("Facturación"),
                      onChanged: admin
                          ? null
                          : (v) => setStateDialog(() => facturacion = v ?? false),
                    ),
                    CheckboxListTile(
                      value: admin,
                      title: const Text("Admin"),
                      onChanged: (v) {
                        setStateDialog(() {
                          admin = v ?? false;
                          if (admin) {
                            inventario = false;
                            facturacion = false;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancelar"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text("Guardar"),
                  onPressed: () async {
                    final rawId = user['id_usuario']; // 👈 CAMBIO AQUÍ
                    if (rawId == null) {
                      debugPrint("⚠️ Error: el usuario no tiene id_usuario válido");
                      return;
                    }

                    // conversión segura a int
                    final userId = rawId is int ? rawId : int.tryParse(rawId.toString());
                    if (userId == null) {
                      debugPrint("⚠️ Error: id_usuario no se pudo convertir a int");
                      return;
                    }

                    // Construir el rol final
                    String rol = "";
                    if (admin) {
                      rol = "ADMIN";
                    } else {
                      List<String> roles = [];
                      if (inventario) roles.add("INVENTARIO");
                      if (facturacion) roles.add("FACTURACION");
                      rol = roles.join("-");
                    }

                    await _usuarioRepo.updateUsuario(
                      id: userId, // 👈 ahora pasamos id_usuario
                      nombreCompleto: nombreCtrl.text,
                      usuario: usuarioCtrl.text,
                      rol: rol,
                      contrasena: contrasenaCtrl.text,
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                    _cargarDatos();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


}
