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
  //final EmailService emailService = EmailService(); // 👈 instancia

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
          decoration: const InputDecoration(
            labelText: "Correo electrónico",
          ),
          validator: (value) {
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final correo = _correoController.text;

              // Guardar en la BD local
              final repo = EmpresaRepository();
              await repo.actualizarCorreoFacturacion(empresaId, correo);

              // Enviar correo de verificación a ti mismo
              await EmailService.enviarCorreoVerificacion(
                correoIngresado: correo,
                empresaId: empresaId,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Correo guardado y notificación enviada")),
                );
                // Guardamos el correo en la configuración global
                ConfiguracionEmail.actualizarCorreo(correo);

              }
            }
          },
          child: const Text("Vincular"),
        ),

      ],
    );
  }
}
