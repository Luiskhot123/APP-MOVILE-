import 'package:flutter/material.dart';
import '../data/app_database.dart'; // ajusta la ruta según tu proyecto

class CrearClientePage extends StatefulWidget {
  const CrearClientePage({Key? key}) : super(key: key);

  @override
  State<CrearClientePage> createState() => _CrearClientePageState();
}

class _CrearClientePageState extends State<CrearClientePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _numeroCtrl = TextEditingController();
  final TextEditingController _razonCtrl = TextEditingController();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();

  int _selectedTipo = 1; // default: Cédula de ciudadanía

  final Map<int, String> _tipos = {
    1: 'Cédula de ciudadanía',
    2: 'NIT',
    3: 'Cédula de extranjería',
  };

  String? _docError; // 👈 para mostrar error en el campo documento

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _razonCtrl.dispose();
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingrese correo';
    final re = RegExp(r"^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$");
    return re.hasMatch(v.trim()) ? null : 'Correo no válido';
  }

  Future<bool> _documentoExiste(String numeroDoc) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'clientes',
      columns: ['id_cliente'],
      where: 'numero_documento = ?',
      whereArgs: [numeroDoc],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> _saveCliente() async {
    if (!_formKey.currentState!.validate()) return;

    final numeroDoc = _numeroCtrl.text.trim();

    // 👇 Verificamos si ya existe
    if (await _documentoExiste(numeroDoc)) {
      setState(() {
        _docError = "Cliente con este número de identificación existente";
      });
      return;
    } else {
      setState(() {
        _docError = null;
      });
    }

    final data = {
      'id_tipo_doc': _selectedTipo,
      'numero_documento': numeroDoc,
      'razon_social': _selectedTipo == 2
          ? _razonCtrl.text.trim() // NIT → usar razón social
          : 'Persona Natural', // CC/CE → forzar Persona Natural
      'nombre_completo': _selectedTipo == 2
          ? 'N/A' // NIT → N/A
          : _nombreCtrl.text.trim(), // CC/CE → obligatorio
      'direccion': _direccionCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'correo': _correoCtrl.text.trim(),
    };

    try {
      final db = await AppDatabase.instance.database;
      await db.insert('clientes', data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente creado correctamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNIT = _selectedTipo == 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<int>(
                value: _selectedTipo,
                items: _tipos.entries
                    .map((e) => DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(e.value),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTipo = v ?? 1),
                decoration: const InputDecoration(labelText: 'Tipo de documento'),
                validator: (v) =>
                (v == null) ? 'Seleccione un tipo de documento' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numeroCtrl,
                decoration: InputDecoration(
                  labelText: 'Número de identificación',
                  errorText: _docError, // 👈 muestra error si ya existe
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingrese número de identificación' : null,
              ),
              const SizedBox(height: 12),
              if (esNIT)
                TextFormField(
                  controller: _razonCtrl,
                  decoration: const InputDecoration(labelText: 'Razón social'),
                  validator: (v) {
                    if (_selectedTipo == 2 && (v == null || v.trim().isEmpty)) {
                      return 'Ingrese razón social';
                    }
                    return null;
                  },
                ),
              if (esNIT) const SizedBox(height: 12),
              if (!esNIT)
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                  validator: (v) {
                    if (_selectedTipo != 2 && (v == null || v.trim().isEmpty)) {
                      return 'Ingrese nombre completo';
                    }
                    return null;
                  },
                ),
              if (!esNIT) const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingrese dirección' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingrese teléfono' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCliente,
                      child: const Text('Guardar cliente'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
