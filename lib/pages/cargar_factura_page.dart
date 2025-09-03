import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import 'crear_producto_page.dart';

class CargarFacturaPage extends StatefulWidget {
  const CargarFacturaPage({super.key});

  @override
  State<CargarFacturaPage> createState() => _CargarFacturaPageState();
}

class _CargarFacturaPageState extends State<CargarFacturaPage> {
  final _formKey = GlobalKey<FormState>();

  String? _proveedor;
  bool _mostrarFormProveedor = false;
  String _medioPago = "EFECTIVO";
  String _estado = "ACTIVA";

  List<Map<String, dynamic>> _productos = [];

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

  void _guardarFactura() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // TODO: Guardar en BD
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Factura guardada con éxito ✅")),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos obligatorios ❌")),
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
            // 🔹 Proveedor
            Text("Proveedor", style: Theme.of(context).textTheme.titleMedium),
            TextFormField(
              decoration: const InputDecoration(hintText: "Buscar o crear proveedor"),
              validator: (val) =>
              val == null || val.isEmpty ? "Proveedor obligatorio" : null,
              onChanged: (val) {
                setState(() {
                  _proveedor = val;
                  _mostrarFormProveedor = true;
                });
              },
            ),
            if (_mostrarFormProveedor) ...[
              const SizedBox(height: 8),
              Text("Nuevo proveedor", style: Theme.of(context).textTheme.titleSmall),
              TextFormField(
                decoration: const InputDecoration(labelText: "Razón social"),
                validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "NIT"),
                validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
              ),
              TextFormField(decoration: const InputDecoration(labelText: "Dirección")),
              TextFormField(decoration: const InputDecoration(labelText: "Teléfono")),
              TextFormField(decoration: const InputDecoration(labelText: "Email")),
              TextFormField(decoration: const InputDecoration(labelText: "Contacto")),
            ],

            const Divider(height: 32),

            // 🔹 Medio de pago
            DropdownButtonFormField<String>(
              value: _medioPago,
              decoration: const InputDecoration(labelText: "Medio de pago"),
              items: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _medioPago = val!),
              validator: (val) =>
              val == null || val.isEmpty ? "Selecciona un medio de pago" : null,
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
