import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/empresa_repository.dart';
import '../data/usuario_repository.dart';
import '../providers/sesion_provider.dart';
import 'dashboard_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _empresaRepo = EmpresaRepository();
  final _usuarioRepo = UsuarioRepository();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _empresaCtrl = TextEditingController();
  final TextEditingController _usuarioCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  List<Map<String, dynamic>> _empresas = [];
  bool _loadingEmpresas = true;
  bool _authLoading = false;
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEmpresas() async {
    try {
      final e = await _empresaRepo.fetchEmpresas();
      setState(() {
        _empresas = e;
        _loadingEmpresas = false;
      });
    } catch (_) {
      setState(() {
        _loadingEmpresas = false;
        _mensajeError = "Error cargando empresas";
      });
    }
  }

  Future<void> _onContinuar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _authLoading = true;
      _mensajeError = null;
    });

    final nombreEmpresa = _empresaCtrl.text.trim();
    final empresa = await _empresaRepo.findByNombre(nombreEmpresa);

    if (empresa == null) {
      setState(() {
        _authLoading = false;
        _mensajeError = "Empresa no encontrada";
      });
      return;
    }

    final user = await _usuarioRepo.autenticar(
      idEmpresa: empresa['id_empresa'] as int,
      usuario: _usuarioCtrl.text.trim(),
      contrasena: _passwordCtrl.text,
    );

    if (user != null) {
      // ✅ Guardar sesión en Riverpod (no usar await aquí)
      ref.read(sesionProvider.notifier).state = SesionState(
        idEmpresa: empresa['id_empresa'] as int,
        usuario: user['usuario']?.toString() ?? '',
      );

      if (!mounted) return;
      // Navegar al Dashboard (ahora sin pasar idEmpresa por constructor)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else {
      setState(() {
        _mensajeError = "Usuario o contraseña incorrectos";
      });
    }

    setState(() => _authLoading = false);
  }

  void _mostrarModalRegistro() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Registro"),
        content: const Text(
          "¿Quieres empezar a gestionar tu inventario con FACTURE o eres empleado de una empresa que ya lo hace?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Soy empleado"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Quiero empezar con Facture"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar sesión")),
      body: _loadingEmpresas
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (text) {
                  final q = text.text.toLowerCase();
                  return _empresas
                      .map((e) => e['nombre'].toString())
                      .where((n) => n.toLowerCase().contains(q));
                },
                onSelected: (selection) => _empresaCtrl.text = selection,
                fieldViewBuilder: (ctx, controller, focusNode, _) {
                  controller.text = _empresaCtrl.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Busca tu empresa",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? "Selecciona una empresa" : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(
                  labelText: "Usuario",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? "Ingrese usuario" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? "Ingrese contraseña" : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _mostrarModalRegistro,
                  child: const Text("¿Aún no estás registrado?"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _authLoading ? null : _onContinuar,
                  child: _authLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Continuar"),
                ),
              ),
              if (_mensajeError != null) ...[
                const SizedBox(height: 12),
                Text(_mensajeError!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
