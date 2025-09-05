import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/facturas_repository.dart';
import '../data/medios_pago_repository.dart';
import '../data/product_repository.dart';
import 'crear_producto_page.dart';
import 'crear_proveedor_page.dart';

class CargarFacturaPage extends StatefulWidget {
  const CargarFacturaPage({super.key});

  @override
  State<CargarFacturaPage> createState() => _CargarFacturaPageState();
}

class _CargarFacturaPageState extends State<CargarFacturaPage> {

  final _formKey = GlobalKey<FormState>();

  String? _proveedor;
  String? _codigoFactura;
  bool _mostrarFormProveedor = false;
  int? _medioPagoId;
  String _medioPago = "EFECTIVO"; // valor por defecto
  String _estado = "ACTIVA";
  int? _proveedorId; // guarda el id_proveedor seleccionado o creado

  Map<String, dynamic> _nuevoProveedorData = {}; // datos si se crea nuevo
  List<Map<String, dynamic>> _productos = [];

  Future<List<Map<String, dynamic>>> _fetchProveedores() async {
    final db = await AppDatabase.instance.database;
    return await db.query(
      "proveedores",
      columns: ["id_proveedor", "nombre"],
    );
  }


  void _addProducto() {
    setState(() {
      _productos.add({
        "producto": null,
        "cantidad": null,
        "precio": null,
        "iva": null,
        "otros": null,
      });
    });
  }

  Future<void> _guardarFactura() async {
    // 1) Validación local del Form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos obligatorios ❌")),
      );
      return;
    }

    _formKey.currentState!.save();
    debugPrint('[_guardarFactura] inicio -> codigo=$_codigoFactura, medio=$_medioPago, proveedorId=$_proveedorId, productos=${_productos.length}');

    try {
      final repo = FacturasRepository();

      // 2) Validar que codigo_factura no sea nulo/vacío
      if (_codigoFactura == null || _codigoFactura!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ingresa el código de la factura")),
        );
        return;
      }

      // 3) Chequear duplicado
      final yaExiste = await repo.existeCodigoFactura(_codigoFactura!.trim());
      if (yaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El código de factura ya existe ❌")),
        );
        return;
      }

      final db = await AppDatabase.instance.database;

      // 4) Si no hay proveedor seleccionado, crear uno (si el mini-form fue llenado)
      if (_proveedorId == null) {
        if (_nuevoProveedorData.isNotEmpty) {
          // valida que tenga al menos 'nombre' (según tu requisito)
          final nombre = (_nuevoProveedorData['nombre'] ?? '').toString().trim();
          if (nombre.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Completa los datos del proveedor antes de guardar")),
            );
            return;
          }
          _proveedorId = await db.insert('proveedores', _nuevoProveedorData);
          debugPrint('[_guardarFactura] proveedor creado id=$_proveedorId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selecciona o crea un proveedor antes de guardar")),
          );
          return;
        }
      }

      // 5) Mapear medio de pago (si tu UI usa String)
      int medioPagoId;
      final mp = _medioPago.toUpperCase();
      if (mp == 'EFECTIVO') {
        medioPagoId = 1;
      } else if (mp == 'TARJETA') {
        medioPagoId = 2;
      } else if (mp == 'TRANSFERENCIA') {
        medioPagoId = 3;
      } else {
        medioPagoId = 1; // fallback
      }

      // 6) Validar líneas de producto y preparar detalles para insertar
      final List<Map<String, dynamic>> detallesParaInsertar = [];
      for (var i = 0; i < _productos.length; i++) {
        final p = _productos[i];
        final prodId = p['producto_id'] as int?;
        if (prodId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("La línea ${i + 1}: selecciona un producto válido")),
          );
          return;
        }

        final cantidad = (p['cantidad'] is int) ? p['cantidad'] as int : int.tryParse(p['cantidad']?.toString() ?? '') ?? 0;
        if (cantidad <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("La línea ${i + 1}: cantidad inválida")),
          );
          return;
        }

        // Precio en DB es INTEGER (precio_unit_base_cop)
        final precioNum = p['precio'];
        int precioUnit;
        if (precioNum is int) {
          precioUnit = precioNum;
        } else if (precioNum is double) {
          precioUnit = precioNum.toInt();
        } else {
          precioUnit = int.tryParse(precioNum?.toString() ?? '') ?? 0;
        }
        if (precioUnit <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("La línea ${i + 1}: precio inválido")),
          );
          return;
        }

        // IVA / retención / otros (aceptamos keys 'iva' o 'iva_pct', y 'retencion'/'retencion_fuente' ...)
        final ivaPct = ((p['iva'] ?? p['iva_pct']) is num) ? (p['iva'] ?? p['iva_pct']) as num : double.tryParse((p['iva'] ?? p['iva_pct'])?.toString() ?? '') ?? 0.0;
        final retFuente = ((p['retencion_fuente'] ?? p['retencion_fuente_pct'] ?? p['retencion']) is num)
            ? (p['retencion_fuente'] ?? p['retencion_fuente_pct'] ?? p['retencion']) as num
            : double.tryParse((p['retencion_fuente'] ?? p['retencion_fuente_pct'] ?? p['retencion'])?.toString() ?? '') ?? 0.0;
        final otrosPct = ((p['otros'] ?? p['otros_impuestos_pct']) is num) ? (p['otros'] ?? p['otros_impuestos_pct']) as num : double.tryParse((p['otros'] ?? p['otros_impuestos_pct'])?.toString() ?? '') ?? 0.0;

        detallesParaInsertar.add({
          'producto_id': prodId,
          'cantidad': cantidad,
          'precio_unit_base_cop': precioUnit,
          'iva_pct': (ivaPct as num).toDouble(),
          'retencion_fuente_pct': (retFuente as num).toDouble(),
          'otros_impuestos_pct': (otrosPct as num).toDouble(),
        });
      } // end for

      debugPrint('[_guardarFactura] detalles preparados: ${detallesParaInsertar.length} líneas');

      // 7) Construir factura
      final factura = {
        'codigo_factura': _codigoFactura!.trim(),
        "tipo": "FACTURA", //siempre FACTURA cuando viene de Cargar Factura
        'estado': _estado,
        'fecha_emision': DateTime.now().toIso8601String(),
        'id_cliente': null,
        'id_medio_pago': medioPagoId,
        'id_proveedor': _proveedorId,
        'tipo2': 'COMPRA',
      };

      // 8) Insertar todo en transacción (FacturasRepository debe implementar insertarFactura/insertarFacturaConDetalles)
      await repo.insertarFactura(factura, detallesParaInsertar);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Factura guardada con éxito ✅")),
      );
      Navigator.pop(context, true);

    } catch (e, st) {
      debugPrint('[_guardarFactura] error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error guardando factura: ${e.toString()}")),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargar Factura")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Codigo de Factura", style: Theme.of(context).textTheme.titleMedium),
            TextFormField(
              decoration: const InputDecoration(labelText: "Código de factura"),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return "Código obligatorio";
                }
                return null; // la validación async se hace en _guardarFactura
              },
              onSaved: (val) {
                _codigoFactura = val!;
              },
            ),
            const SizedBox(height: 16),
            // 🔹 Campo Proveedor con Autocomplete (basado en "nombre")
            Text("Proveedor", style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchProveedores(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const CircularProgressIndicator();
                }
                final proveedores = snap.data!;
                final nombres = proveedores.map((p) => p['nombre'] as String).toList();

                return Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) return const Iterable<String>.empty();

                    final matches = nombres
                        .where((p) => p.toLowerCase().contains(query))
                        .toList();

                    // 👇 añadimos opción de crear proveedor si no existe
                    if (!nombres.map((e) => e.toLowerCase()).contains(query)) {
                      matches.add("Crear proveedor: ${textEditingValue.text}");
                    }
                    return matches;
                  },
                  onSelected: (seleccion) async {
                    if (seleccion.startsWith("Crear proveedor:")) {
                      // Abrir modal con CrearProveedorPage
                      final nuevoProveedor = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (_) => Dialog(
                          child: SizedBox(
                            width: double.infinity,
                            height: 600, // ajusta según necesites
                            child: CrearProveedorPage(esModal: true),
                          ),
                        ),
                      );

                      if (nuevoProveedor != null) {
                        setState(() {
                          _proveedorId = null;
                          _proveedor = ''; // vaciamos el campo
                        });
                      }
                    } else {
                      final prov = proveedores.firstWhere((p) => p['nombre'] == seleccion);
                      setState(() {
                        _proveedorId = prov['id_proveedor'];
                        _proveedor = prov['nombre'];
                      });
                    }
                  },

                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    controller.text = _proveedor ?? controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: "Buscar o crear proveedor",
                      ),
                      validator: (val) =>
                      val == null || val.isEmpty ? "Proveedor obligatorio" : null,
                    );
                  },
                );
              },
            ),

            const Divider(height: 32),

            // 🔹 Medio de pago
            FutureBuilder<List<Map<String, dynamic>>>(
              future: MediosPagoRepository().fetchMediosPago(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final medios = snapshot.data!;

                return DropdownButtonFormField<int>(
                  value: _medioPagoId,
                  decoration: const InputDecoration(labelText: "Medio de pago"),
                  items: medios.map((mp) {
                    return DropdownMenuItem<int>(
                      value: mp["id_medio_pago"] as int,
                      child: Text(mp["codigo"] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _medioPagoId = val),
                  validator: (val) =>
                  val == null ? "Selecciona un medio de pago" : null,
                );
              },
            ),

            const SizedBox(height: 16),

            // 🔹 Estado
            DropdownButtonFormField<String>(
              value: _estado,
              decoration: const InputDecoration(labelText: "Estado de la factura"),
              items: ["ACTIVA", "ANULADA", "NOTA_CREDITO", "NOTA_DEBITO"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _estado = val!),
              validator: (val) =>
              val == null || val.isEmpty ? "Selecciona un estado" : null,
            ),

            const Divider(height: 32),

            // 🔹 Productos
            Text("Productos", style: Theme.of(context).textTheme.titleMedium),
            ..._productos.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: ProductRepository().fetchProductosLite(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const CircularProgressIndicator();
                          }
                          final productos = snap.data!;
                          final nombres = productos.map((p) => p['nombre'] as String).toList();

                          return Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              final query = textEditingValue.text.trim().toLowerCase();
                              if (query.isEmpty) return const Iterable<String>.empty();

                              final matches = nombres
                                  .where((p) => p.toLowerCase().contains(query))
                                  .toList();

                              if (!nombres.map((e) => e.toLowerCase()).contains(query)) {
                                matches.add("El producto no existe, desea crear: ${textEditingValue.text}");
                              }

                              return matches;
                            },
                            onSelected: (seleccion) async {
                              if (seleccion.startsWith("El producto no existe")) {
                                final nuevoNombre = seleccion.split(":").last.trim();
                                await _abrirCrearProducto(nuevoNombre);
                                setState(() {});
                              } else {
                                final producto = productos.firstWhere((p) => p['nombre'] == seleccion);
                                setState(() {
                                  item["producto_id"] = producto['id_producto'];
                                  item["producto_nombre"] = producto['nombre'];

                                  // 👇 Guardamos automáticamente impuestos desde BD
                                  item["iva"] = producto['iva_pct'] ?? 0.0;
                                  item["retencion_fuente"] = producto['retencion_fuente_pct'] ?? 0.0;
                                  item["otros"] = producto['otros_impuestos_pct'] ?? 0.0;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "Cantidad"),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                final n = int.tryParse(val ?? "");
                                if (n == null || n <= 0) return "Cantidad inválida";
                                return null;
                              },
                              onSaved: (val) =>
                              item["cantidad"] = int.tryParse(val ?? "0") ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: "Precio"),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                final n = double.tryParse(val ?? "");
                                if (n == null || n <= 0) return "Precio inválido";
                                return null;
                              },
                              onSaved: (val) =>
                              item["precio"] = double.tryParse(val ?? "0.0") ?? 0.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            TextButton.icon(
              onPressed: _addProducto,
              icon: const Icon(Icons.add),
              label: const Text("Añadir producto"),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _guardarFactura,
              child: const Text("Guardar factura"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirCrearProducto(String nombreInicial) async {
    final result = await Navigator.pushNamed(
      context,
      '/crear_producto',
      arguments: {"nombreInicial": nombreInicial},
    );

    if (result == true) {
      setState(() {});
    }
  }
}
