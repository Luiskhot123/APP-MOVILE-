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

  Future<void> _abrirScanner() async {
    // Navegamos a una pantalla con el escáner
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
              _buildField("id_categoria", "ID Categoría", TextInputType.number),
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

              _buildField("id_unidad", "ID Unidad", TextInputType.number),
              _buildField("costo_compra_cop", "Costo compra", TextInputType.number),
              _buildField("precio_base_cop", "Precio base", TextInputType.number),
              _buildField("iva_pct", "IVA %", TextInputType.number),
              _buildField("retencion_fuente_pct", "Retención %", TextInputType.number),
              _buildField("otros_impuestos_pct", "Otros impuestos %", TextInputType.number),
              _buildField("stock", "Stock", TextInputType.number),
              _buildField("activo", "Activo (1/0)", TextInputType.number),

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
