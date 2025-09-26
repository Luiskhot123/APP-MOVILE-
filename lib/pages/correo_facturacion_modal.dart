import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/empresa_repository.dart';
import '../services/configuracion_email.dart';
import '../services/email_service.dart'; // 👈 Ajusta la ruta según tu proyecto
import '../providers/sesion_provider.dart'; // 👈 Ajusta la ruta según tu proyecto

/// Modal informativo con el signo de interrogación
class InfoCorreoFacturacionModal extends StatelessWidget {
  const InfoCorreoFacturacionModal({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Información"),
      content: const Text(
        "Aquí deberás registrar el correo con el cual facturas electrónicamente "
            "(correo desde el cual envías la factura al cliente).\n\n"
            "Luego de hacerlo, en un tiempo máximo de 2 horas podrás estar "
            "facturando electrónicamente con normalidad.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }
}

/// Modal para registrar correo facturación
class CorreoFacturacionModal extends ConsumerStatefulWidget {
  const CorreoFacturacionModal({super.key});

  @override
  ConsumerState<CorreoFacturacionModal> createState() =>
      _CorreoFacturacionModalState();
}

class _CorreoFacturacionModalState
    extends ConsumerState<CorreoFacturacionModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _correoController = TextEditingController();

  bool _modoEdicion = false; // 👈 Controla si estamos en modo edición
  String? _correoOriginal; // 👈 Guardamos el correo original de la DB

  @override
  void initState() {
    super.initState();
    _cargarCorreo();
  }

  Future<void> _cargarCorreo() async {
    final sesion = ref.read(sesionProvider);
    final empresaId = sesion?.idEmpresa ?? 0;
    final repo = EmpresaRepository();

    final correo = await repo.obtenerCorreoFacturacion(empresaId);

    if (correo != null) {
      setState(() {
        _correoController.text = correo;
        _correoOriginal = correo; // 👈 Guardamos original
        _modoEdicion = false; // 👈 Inicialmente bloqueado
      });
    } else {
      setState(() {
        _modoEdicion = true; // 👈 Si no hay correo, habilitado
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Aquí obtenemos la sesión desde Riverpod
    final sesion = ref.watch(sesionProvider);
    final empresaId = sesion?.idEmpresa ?? 0;


    return AlertDialog(
      title: const Text("Correo facturación"),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _correoController,
          enabled: _modoEdicion, // 👈 Bloquea o habilita
          decoration: const InputDecoration(
            labelText: "Correo electrónico",
          ),
          validator: (value) {
            if (!_modoEdicion) return null; // 👈 Si está bloqueado no validar
            if (value == null || value.isEmpty) {
              return "El correo es obligatorio";
            }
            final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!regex.hasMatch(value)) {
              return "Correo inválido";
            }
            return null;
          },
        ),
      ),
      actions: _modoEdicion
          ? [
        TextButton(
          onPressed: () {
            // 👇 Restauramos correo original y bloqueamos edición
            setState(() {
              _correoController.text = _correoOriginal ?? "";
              _modoEdicion = false;
            });
          },
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final correo = _correoController.text;

              final repo = EmpresaRepository();
              await repo.actualizarCorreoFacturacion(empresaId, correo);

              await EmailService.enviarCorreoVerificacion(
                correoIngresado: correo,
                empresaId: empresaId,
              );

              if (context.mounted) {
                Navigator.pop(context);
                await _mostrarModalCorreoExitoso(context);
                ConfiguracionEmail.actualizarCorreo(correo);
              }
            }
          },
          child: const Text("Guardar"),
        ),
      ]
          : [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
        ElevatedButton(
          onPressed: () => _mostrarConfirmacion(context),
          child: const Text("Modificar"),
        ),
      ],
    );
  }
  Future<void> _mostrarConfirmacion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar"),
        content: const Text(
            "¿Está seguro de que quiere modificar el correo de facturación?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        _modoEdicion = true; // 👈 Habilita edición
      });
    }
  }
  Future<void> _mostrarModalCorreoExitoso(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¡Éxito!"),
        content: const Text("El correo fue vinculado correctamente."),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
    setState(() {
      _modoEdicion = false; // 👈 Volvemos al estado bloqueado
    });
  }

}
