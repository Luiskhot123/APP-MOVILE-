import 'package:flutter/material.dart';
import '../data/app_database.dart';

class CrearProveedorPage extends StatefulWidget {
  final bool esModal;
  const CrearProveedorPage({super.key, this.esModal = false});

  @override
  State<CrearProveedorPage> createState() => _CrearProveedorPageState();
}

class _CrearProveedorPageState extends State<CrearProveedorPage> {
  final _formKey = GlobalKey<FormState>();

  String? nombre;
  String? razonSocial;
  String? nit;
  String? direccion;
  String? telefono;
  String? email;
  String? contacto;

  Future<void> _guardarProveedor() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final db = await AppDatabase.instance.database;

    final nuevoProveedor = {
      "nombre": nombre!.trim(),
      "razon_social": razonSocial!.trim(),
      "nit": nit!.trim(),
      "direccion": direccion!.trim(),
      "telefono": telefono!.trim(),
      "email": email!.trim(),
      "contacto": contacto!.trim(),
    };

    final id = await db.insert('proveedores', nuevoProveedor);

    // Retornamos datos completos
    final result = {
      'id_proveedor': id,
      'nombre': nombre!.trim(),
      'razon_social': razonSocial!.trim(),
      'nit': nit!.trim(),
    };

    if (widget.esModal) {
      Navigator.pop(context, result);
    } else {
      Navigator.pop(context); // solo cerrar pantalla completa
    }
  }

  String? _validarEmail(String? val) {
    if (val == null || val.isEmpty) return 'Email requerido';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(val) ? null : 'Email inválido';
  }

  String? _validarTelefono(String? val) {
    if (val == null || val.isEmpty) return 'Teléfono requerido';
    final regex = RegExp(r'^\+?[0-9]{7,15}$');
    return regex.hasMatch(val) ? null : 'Teléfono inválido';
  }

  String? _validarNIT(String? val) {
    if (val == null || val.isEmpty) return 'NIT requerido';
    final regex = RegExp(r'^[0-9]+$');
    return regex.hasMatch(val) ? null : 'NIT inválido';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.esModal ? 'Crear Proveedor' : 'Nuevo Proveedor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => nombre = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Razón social'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => razonSocial = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'NIT'),
                validator: _validarNIT,
                onSaved: (v) => nit = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => direccion = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Teléfono'),
                validator: _validarTelefono,
                onSaved: (v) => telefono = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _validarEmail,
                onSaved: (v) => email = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Contacto'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => contacto = v,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardarProveedor,
                child: const Text('Guardar proveedor'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
