import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/product_repository.dart';

class CrearProductoPage extends StatefulWidget {
  const CrearProductoPage({super.key});

  @override
  State<CrearProductoPage> createState() => _CrearProductoPageState();
}

class _CrearProductoPageState extends State<CrearProductoPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  String? codigoBarras;

  // Dropdown opciones
  int? categoriaSeleccionada;
  int? unidadSeleccionada;

  Future<void> _abrirScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );

    if (result != null && result is String) {
      setState(() {
        codigoBarras = result;
        _formData["codigo_barras"] = result;
      });
    }
  }

  Future<void> _guardar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Guardar seleccionados de dropdown
      _formData["id_categoria"] = categoriaSeleccionada;
      _formData["id_unidad"] = unidadSeleccionada;

      // Activo siempre en 1
      _formData["activo"] = 1;

      await ProductRepository().insertProduct(_formData);
      Navigator.pop(context, true); // volvemos a inventario
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear Producto")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField("nombre", "Nombre", TextInputType.text),
              _buildField("descripcion", "Descripción", TextInputType.text),

              // 👇 Categoría con dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Categoría"),
                value: categoriaSeleccionada,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Abarrotes")),
                  DropdownMenuItem(value: 2, child: Text("Lácteos")),
                  DropdownMenuItem(value: 3, child: Text("Bebidas")),
                  DropdownMenuItem(value: 4, child: Text("Aseo")),
                ],
                onChanged: (val) {
                  setState(() => categoriaSeleccionada = val);
                },
                validator: (val) => val == null ? "Seleccione una categoría" : null,
              ),

              _buildField("sku", "SKU", TextInputType.text),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "Código de barras"),
                      controller: TextEditingController(text: codigoBarras ?? ""),
                      readOnly: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _abrirScanner,
                  ),
                ],
              ),

              // 👇 Unidad de medida con dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Unidad de medida"),
                value: unidadSeleccionada,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Unidad")),
                  DropdownMenuItem(value: 2, child: Text("Kilogramo")),
                  DropdownMenuItem(value: 3, child: Text("Litro")),
                  DropdownMenuItem(value: 4, child: Text("Paquete")),
                ],
                onChanged: (val) {
                  setState(() => unidadSeleccionada = val);
                },
                validator: (val) => val == null ? "Seleccione una unidad" : null,
              ),

              _buildField("costo_compra_cop", "Costo compra", TextInputType.number),
              _buildField("precio_base_cop", "Precio base", TextInputType.number),
              _buildField("iva_pct", "IVA %", TextInputType.number),
              _buildField("retencion_fuente_pct", "Retención %", TextInputType.number),
              _buildField("otros_impuestos_pct", "Otros impuestos %", TextInputType.number),
              _buildField("stock", "Stock", TextInputType.number),

              // 👇 Nuevo campo Bajo stock
              _buildField("bajo_stock", "Bajo stock a partir de...", TextInputType.number),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardar,
                child: const Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String key, String label, TextInputType type) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      keyboardType: type,
      validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
      onSaved: (val) => _formData[key] = val,
    );
  }
}

class _ScannerPage extends StatelessWidget {
  const _ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear código")),
      body: MobileScanner(
        onDetect: (barcodeCapture) {
          final String? code = barcodeCapture.barcodes.first.rawValue;
          if (code != null) {
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
