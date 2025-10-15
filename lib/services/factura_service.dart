import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/cliente_repository.dart';
import '../data/facturas_repository.dart';
import '../data/deudores_repository.dart';
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
    double abonoInicial = 0.0;
    int medioPago = 1; // Por defecto EFECTIVO

    // Paso 2️⃣: si es crédito, validar cliente y seleccionar plazo
    if (formaPago == 2) {
      cliente ??= await mostrarModalValidacionCliente(context);
      if (cliente == null) return; // Cancelado

      // 🔹 Nuevo: preguntar si desea abonar algo
      final deseaAbonar = await _preguntarDeseaAbonar(context);
      if (deseaAbonar == null) return; // Cancelado

      if (deseaAbonar) {
        abonoInicial = await _ingresarAbonoInicial(context, totalCOP) ?? 0.0;
        // Luego de abonar, seleccionar medio de pago normal
        final medioSeleccionado = await _seleccionarMedioPago(context);
        if (medioSeleccionado == null) return;
        medioPago = medioSeleccionado;
      } else {
        // No desea abonar, se pasa por defecto EFECTIVO
        medioPago = 1;
      }

      plazoDias = await _seleccionarPlazoCredito(context) ?? 0;
      if (plazoDias == 0) return; // Cancelado
    } else {
      // Si es CONTADO
      final medioSeleccionado = await _seleccionarMedioPago(context);
      if (medioSeleccionado == null) return;
      medioPago = medioSeleccionado;
    }

    // Paso 3️⃣: preparar datos de factura
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
      // Paso 4️⃣: guardar factura
      final idFactura = await repo.insertarFactura(facturaData, detalles);

      // Paso 5️⃣: si es crédito, registrar en tabla 'deudores'
      if (formaPago == 2) {
        final idCliente = cliente?.idCliente;
        if (idCliente != null) {
          final deudor = Deudor(
            idFactura: idFactura,
            idCliente: idCliente,
            plazo: plazoDias,
            abono: abonoInicial, // Abono acumulado inicial
          );
          await DeudoresRepository().insertarDeudor(deudor);
        }
      }

      // Paso 6️⃣: generar PDF
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

      if (cliente?.correo?.isNotEmpty == true) {
        await EmailService.enviarFactura(
          destinatario: cliente!.correo!,
          nombreDestinatario:
          cliente.nombreCompleto ?? cliente.razonSocial ?? "Cliente",
          pdfBytes: pdfData,
          asunto: "Factura de tu compra en Fashion Line",
        );
      }

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


  // Preguntar si desea abonar algo
  static Future<bool?> _preguntarDeseaAbonar(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Desea abonar algún monto?"),
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
  }
  // Modal para ingresar el abono inicial
  static Future<double?> _ccxxx(BuildContext context, int total) async {
    final controller = TextEditingController();
    double? valor;

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Ingrese monto del abono"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: "\$ ",
                hintText: "Ej: 5,000",
              ),
              onChanged: (val) {
                val = val.replaceAll(RegExp(r'[^0-9]'), '');
                if (val.isEmpty) return;
                final numValue = int.parse(val);
                if (numValue > total) {
                  controller.text = total.toString();
                  controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length));
                } else {
                  controller.text = _formatNumber(numValue);
                  controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length));
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                  valor = double.tryParse(text) ?? 0.0;
                  Navigator.pop(ctx, valor);
                },
                child: const Text("Confirmar"),
              ),
            ],
          );
        });
      },
    );
  }

// Formatear número con comas
  static String _formatNumber(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i != 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // 🔹 Ingresar monto de abono
  static Future<double?> _ingresarAbonoInicial(BuildContext context, int totalCOP) {
    final controller = TextEditingController();
    final formatter = NumberFormat('#,###', 'es_CO');

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Ingrese monto de abono"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Monto (máx: ${formatter.format(totalCOP)})",
                prefixText: "\$ ",
              ),
              onChanged: (val) {
                final raw = val.replaceAll(RegExp(r'[^0-9]'), '');
                final parsed = int.tryParse(raw) ?? 0;
                if (parsed > totalCOP) {
                  controller.text = formatter.format(totalCOP);
                } else {
                  controller.text = formatter.format(parsed);
                }
                controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length));
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  final raw =
                  controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final val = double.tryParse(raw) ?? 0.0;
                  if (val > totalCOP) return;
                  Navigator.pop(ctx, val);
                },
                child: const Text("Aceptar"),
              ),
            ],
          );
        });
      },
    );
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
    int tipoSeleccionado = 1;
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
                      decoration:
                      const InputDecoration(labelText: 'Tipo documento'),
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
                                content:
                                Text('Cliente creado, vuelva a validar'),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Regresar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
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
