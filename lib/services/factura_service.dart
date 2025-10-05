import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../data/cliente_repository.dart';
import '../data/facturas_repository.dart';
import '../providers/sesion_provider.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../models/cliente.dart';
import '../models/venta_item.dart';
import '../pages/crear_cliente_page.dart';

class FacturaService {
  static Future<void> procesarVenta({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, VentaItem> carrito,
    required int totalCOP,
    Cliente? cliente,
  }) async {
    // Paso 1️⃣: seleccionar forma de pago (Contado / Crédito)
    final formaPago = await _seleccionarFormaPago(context);
    if (formaPago == null) return;

    int plazoDias = 0;

    // Paso 2️⃣: si es crédito, validar cliente y seleccionar plazo
    if (formaPago == 2) {
      cliente ??= await mostrarModalValidacionCliente(context);
      if (cliente == null) return; // Cancelado

      plazoDias = await _seleccionarPlazoCredito(context) ?? 0;
      if (plazoDias == 0) return; // Cancelado
    }

    // Paso 3️⃣: seleccionar medio de pago
    final medioPago = await _seleccionarMedioPago(context);
    if (medioPago == null) return;

    // Paso 4️⃣: preparar datos de factura
    final repo = FacturasRepository();

    final facturaData = {
      "tipo": "FACTURA",
      "tipo2": "VENTA",
      "estado": "ACTIVA",
      "fecha_emision": DateTime.now().toIso8601String().split('T').first,
      "id_cliente": cliente?.idCliente,
      "id_medio_pago": medioPago,
      "forma_pago_id": formaPago,
      "id_proveedor": null,
    };

    final detalles = carrito.values.map((item) => {
      "producto_id": item.product.id,
      "cantidad": item.qty,
      "precio_unit_base_cop": item.product.precio.toInt(),
      "iva_pct": item.product.ivaPct,
      "retencion_fuente_pct": 0.0,
      "otros_impuestos_pct": 0.0,
    }).toList();

    try {
      // Paso 5️⃣: guardar factura
      final idFactura = await repo.insertarFactura(facturaData, detalles);

      // Paso 6️⃣: definir datos del adquiriente
      final adquiriente = cliente ??
          Cliente(
            idCliente: -1,
            idTipoDoc: 1,
            numeroDocumento: "222222222",
            nombreCompleto: "Consumidor Final",
            razonSocial: "Consumidor Final",
            direccion: "N/A",
            telefono: "N/A",
            correo: "",
          );

      // Paso 7️⃣: generar PDF
      final pdfData = await PDFService.generarFacturaDIAN(
        numeroFactura: idFactura.toString(),
        fecha: DateTime.now(),
        medioPago: medioPago,
        formaPago: formaPago,
        carrito: carrito,
        totalCOP: totalCOP.toDouble(),
        ivaTotal: carrito.values
            .map((e) => (e.product.precio * e.qty) * (e.product.ivaPct / 100))
            .fold(0.0, (a, b) => a + b),
        nombreEmisor: ref.read(sesionProvider)!.nombreEmpresa,
        nitEmisor: ref.read(sesionProvider)!.nit,
        direccionEmisor: ref.read(sesionProvider)!.direccion,
        resolucionDIAN: ref.read(sesionProvider)!.resolucionDian,
        claveTecnica: ref.read(sesionProvider)!.claveTecnica,
        tipoAmbiente: ref.read(sesionProvider)!.tipoAmbiente,
        cliente: adquiriente,
      );

      // Paso 8️⃣: enviar correo solo si hay cliente con email
      if (cliente?.correo?.isNotEmpty == true) {
        await EmailService.enviarFactura(
          destinatario: cliente!.correo!,
          nombreDestinatario:
          cliente.nombreCompleto ?? cliente.razonSocial ?? "Cliente",
          pdfBytes: pdfData,
          asunto: "Factura de tu compra en Fashion Line",
        );
      }

      // Paso 9️⃣: imprimir PDF
      await Printing.layoutPdf(onLayout: (format) async => pdfData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Factura registrada con éxito ✅")),
        );
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (context.mounted) {
        debugPrint("❌ Error guardando factura: $e");
        debugPrint("📌 Stacktrace: $st");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error guardando factura: $e")),
        );
      }
    }
  }

  // 🔹 Modal de forma de pago
  static Future<int?> _seleccionarFormaPago(BuildContext context) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seleccione forma de pago"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text("CONTADO"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text("CRÉDITO"),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Modal de medio de pago
  static Future<int?> _seleccionarMedioPago(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seleccione medio de pago"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 1),
                child: const Text("EFECTIVO")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 2),
                child: const Text("TARJETA")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 3),
                child: const Text("TRANSFERENCIA")),
          ],
        ),
      ),
    );
  }

  // 🔹 Modal de selección de plazo crédito
  static Future<int?> _seleccionarPlazoCredito(BuildContext context) async {
    int? selected = 8;
    final customCtrl = TextEditingController();
    bool otroSeleccionado = false;

    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Seleccione plazo de crédito"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final dias in [8, 15, 30])
                  RadioListTile<int>(
                    value: dias,
                    groupValue: selected,
                    title: Text("$dias días"),
                    onChanged: (v) {
                      setState(() {
                        selected = v;
                        otroSeleccionado = false;
                      });
                    },
                  ),
                RadioListTile<int>(
                  value: 0,
                  groupValue: otroSeleccionado ? 0 : selected,
                  title: const Text("Otro"),
                  onChanged: (v) {
                    setState(() {
                      otroSeleccionado = true;
                      selected = null;
                    });
                  },
                ),
                if (otroSeleccionado)
                  TextField(
                    controller: customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Ingrese días", hintText: "Ej: 45"),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (otroSeleccionado) {
                    final val = int.tryParse(customCtrl.text);
                    if (val == null || val <= 0) return;
                    Navigator.pop(ctx, val);
                  } else {
                    Navigator.pop(ctx, selected);
                  }
                },
                child: const Text("Aceptar"),
              )
            ],
          );
        });
      },
    );
  }

  // 🔹 Modal de validación de cliente
  static Future<Cliente?> mostrarModalValidacionCliente(
      BuildContext context) async {
    final repo = ClienteRepository();
    final formKey = GlobalKey<FormState>();
    final numeroCtrl = TextEditingController();
    int tipoSeleccionado = 1; // default CC
    String? errorDoc;

    final tipos = {
      1: 'Cédula de ciudadanía',
      2: 'NIT',
      3: 'Cédula de extranjería',
    };

    return showDialog<Cliente>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Validar cliente'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: tipoSeleccionado,
                      items: tipos.entries
                          .map((e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => tipoSeleccionado = v ?? 1),
                      decoration: const InputDecoration(
                          labelText: 'Tipo documento'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: numeroCtrl,
                      decoration: InputDecoration(
                        labelText: 'Número de identificación',
                        errorText: errorDoc,
                      ),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ingrese número' : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          final creado = await showDialog(
                            context: context,
                            builder: (_) => const CrearClientePage(),
                          );
                          if (creado == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cliente creado, vuelva a validar'),
                              ),
                            );
                          }
                        },
                        child: const Text("Crear cliente",
                            style: TextStyle(
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final cliente = await repo.findByTipoYDocumento(
                        tipoSeleccionado, numeroCtrl.text.trim());
                    if (cliente == null) {
                      setState(() => errorDoc = "Cliente inexistente");
                    } else {
                      Navigator.pop(ctx, cliente);
                    }
                  },
                  child: const Text("Continuar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  static Future<void> confirmarCancelarVenta(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desea cancelar la venta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // cerrar modal
            child: const Text('Regresar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), // confirmar cancelar
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (salir == true && context.mounted) {
      Navigator.pop(context, false);
    }
  }
}
