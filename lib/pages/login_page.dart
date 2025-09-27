import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/empresa_repository.dart';
import '../data/usuario_repository.dart';
import '../data/vinculacion_repository.dart';
import '../providers/sesion_provider.dart';
import 'dashboard_page.dart';
import 'inventory_page.dart';
import 'facturas_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

String _roleIntToString(int r) {
  switch (r) {
    case 1:
      return 'ADMIN';
    case 2:
      return 'FACTURACION';
    case 3:
      return 'INVENTARIO';
    case 4:
      return 'INVENTARIO-FACTURACION';
    default:
      return 'UNKNOWN';
  }
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
      // ✅ Guardar sesión en Riverpod
      ref.read(sesionProvider.notifier).state = SesionState(
        idEmpresa: empresa['id_empresa'] as int,
        usuario: user['usuario']?.toString() ?? '',
        rol: user['rol'],
        nombreEmpresa: empresa['nombre']?.toString() ?? '',
        nit: empresa['nit']?.toString() ?? '',
        direccion: empresa['direccion']?.toString() ?? '',
        // Dummy hasta que tengas integración DIAN
        resolucionDian: '0000000000',
        claveTecnica: 'CLAVE_DUMMY',
        tipoAmbiente: 'PRUEBAS', // pruebas
      );


      if (!mounted) return;

      final rol = user['rol']?.toString().toUpperCase();

      // ✅ Redirección según rol
      if (rol == "ADMIN") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );

      } else if (rol == "INVENTARIO") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InventoryStandalone()),
        );
      } else if (rol == "FACTURACION") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FacturasStandalone()),
        );
      } else {
        setState(() {
          _mensajeError = "Rol no permitido";
        });
      }
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
            onPressed: () {
              Navigator.pop(ctx); // cierra primer modal
              _mostrarRegistroEmpleado(); // abre el modal de empleado
            },
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

  Future<void> _mostrarRegistroEmpleado() async {
    final VinculacionRepository vincRepo = VinculacionRepository();
    final TextEditingController codigoCtrl = TextEditingController();
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController usuarioNewCtrl = TextEditingController();
    final TextEditingController contrasenaNewCtrl = TextEditingController();

    bool verified = false;
    String empresaNombre = '';
    int? empresaId;
    int? roleInt;
    bool loadingVerify = false;
    bool loadingRegister = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Registro - Soy empleado"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Empresa (solo lectura)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text("Tu empresa", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      empresaNombre.isEmpty ? '—' : empresaNombre,
                      style: TextStyle(color: empresaNombre.isEmpty ? Colors.grey : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Código de vinculación
                  TextField(
                    controller: codigoCtrl,
                    decoration: InputDecoration(
                      labelText: "Código de vinculación (20 dígitos)",
                      hintText: "Ingresa tu codigo",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("¿Cómo conseguir el código?"),
                              content: const Text("Debes solicitar el código de vinculación al administrador de la app en tu empresa."),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                            ),
                          );
                        },
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                  ),

                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: loadingVerify
                        ? null
                        : () async {
                      final code = codigoCtrl.text.trim();
                      if (!RegExp(r'^\d{20}$').hasMatch(code)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El código debe tener 20 dígitos numéricos.')));
                        return;
                      }
                      setStateDialog(() => loadingVerify = true);

                      // 1) intentamos validar contra la tabla de códigos (si existe)
                      final validated = await vincRepo.validateCode(code);

                      if (validated != null) {
                        // válido en tabla: toma id_empresa y rol de ahí
                        final rawId = validated['id_empresa'];
                        final rawRol = validated['rol'];
                        empresaId = (rawId is int) ? rawId : int.tryParse(rawId.toString());
                        roleInt = (rawRol is int) ? rawRol : int.tryParse(rawRol.toString());
                        // buscar nombre empresa
                        if (empresaId != null) {
                          final empresaRow = await _empresaRepo.findById(empresaId!);
                          empresaNombre = empresaRow?['nombre']?.toString() ?? 'Empresa #$empresaId';
                          setStateDialog(() {
                            verified = true;
                            loadingVerify = false;
                          });
                        } else {
                          setStateDialog(() {
                            loadingVerify = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código inválido (empresa).')));
                        }
                      } else {
                        // ❌ Código inválido, no hacer fallback
                        setStateDialog(() => loadingVerify = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código inválido o expirado.')),
                        );
                      }
                    },
                    child: loadingVerify ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verificar código'),
                  ),

                  const SizedBox(height: 12),

                  // Mostrar formulario sólo después de verificación
                  if (verified) ...[
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: "Nombre/s y Apellidos"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usuarioNewCtrl,
                      decoration: const InputDecoration(labelText: "Usuario"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contrasenaNewCtrl,
                      decoration: const InputDecoration(labelText: "Contraseña"),
                      obscureText: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancelar"),
              ),
              if (verified)
                ElevatedButton(
                  onPressed: loadingRegister
                      ? null
                      : () async {
                    final nombreFull = nombreCtrl.text.trim();
                    final usuarioNuevo = usuarioNewCtrl.text.trim();
                    final contrasenaNueva = contrasenaNewCtrl.text;

                    if (nombreFull.isEmpty || usuarioNuevo.isEmpty || contrasenaNueva.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos.')));
                      return;
                    }

                    if (empresaId == null || roleInt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error interno: datos de verificación incompletos.')));
                      return;
                    }

                    setStateDialog(() => loadingRegister = true);

                    try {
                      // Insertar el usuario (rol como entero)
                      final newId = await _usuarioRepo.insertUsuario(
                        idEmpresa: empresaId!,
                        usuario: usuarioNuevo,
                        contrasena: contrasenaNueva,
                        nombreCompleto: nombreFull,
                        rol: roleInt!, // entero
                      );

                      // Si el código estaba en la tabla, marcarlo como usado
                      final code = codigoCtrl.text.trim();
                      final existCode = await vincRepo.validateCode(code);
                      if (existCode != null) {
                        await vincRepo.markUsed(code);
                      }

                      // Auto-login: guardar sesión (convertimos a texto para SesionState)
                      final roleStr = _roleIntToString(roleInt!);

                      // Traer la empresa de la DB
                      final empresaRepo = EmpresaRepository();
                      final empresa = await empresaRepo.findById(empresaId!);

                      if (empresa == null) {
                        throw Exception("No se encontró la empresa con id $empresaId");
                      }

                      ref.read(sesionProvider.notifier).state = SesionState(
                        idEmpresa: empresaId!,
                        usuario: usuarioNuevo,
                        rol: roleStr,
                        nombreEmpresa: empresa['nombre'] as String,
                        nit: empresa['nit'] as String,
                        direccion: empresa['direccion'] as String,
                        // Dummy DIAN hasta tener reales
                        resolucionDian: "1234567890",
                        claveTecnica: "CLAVE_DUMMY",
                        tipoAmbiente: "PRUEBAS", // pruebas
                      );

                      // navega según rol
                      if (!mounted) return;
                      Navigator.pop(context); // cierra dialog
                      // redirecciones:
                      if (roleInt == 1) {
                        // ADMIN -> Dashboard
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
                      } else if (roleInt == 2) {
                        // FACTURACION
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacturasStandalone()));
                      } else if (roleInt == 3) {
                        // INVENTARIO
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const InventoryStandalone()));
                      } else if (roleInt == 4) {
                        // Ambos -> Home (tabs)
                        Navigator.pushReplacementNamed(context, '/home');
                      } else {
                        // fallback
                        Navigator.pushReplacementNamed(context, '/home');
                      }

                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada correctamente.')));
                    } catch (e) {
                      setStateDialog(() => loadingRegister = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creando usuario: $e')));
                    }
                  },
                  child: loadingRegister ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Registrar'),
                ),
            ],
          );
        });
      },
    );

    // limpia controllers (opcional)
    codigoCtrl.dispose();
    nombreCtrl.dispose();
    usuarioNewCtrl.dispose();
    contrasenaNewCtrl.dispose();
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
                onSelected: (selection) =>
                _empresaCtrl.text = selection,
                fieldViewBuilder: (ctx, controller, focusNode, _) {
                  controller.text = _empresaCtrl.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Busca tu empresa",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? "Selecciona una empresa"
                        : null,
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
                validator: (v) =>
                v == null || v.isEmpty ? "Ingrese usuario" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => v == null || v.isEmpty
                    ? "Ingrese contraseña"
                    : null,
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
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text("Continuar"),
                ),
              ),
              if (_mensajeError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _mensajeError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
