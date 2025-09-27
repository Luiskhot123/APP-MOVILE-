import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../data/facturas_repository.dart';
import '../providers/sesion_provider.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../models/cliente.dart';
import '../models/venta_item.dart';

class FacturaService {
  static Future<void> procesarVenta({
    required BuildContext context,
    required WidgetRef ref, // 👈 para acceder a sesionProvider
    required Map<String, VentaItem> carrito,
    required int totalCOP,
    Cliente? cliente,
  }) async {
    // Paso 1: seleccionar medio de pago
    final medioPago = await _seleccionarMedioPago(context);
    if (medioPago == null) return;

    // Paso 2: preparar datos
    final repo = FacturasRepository();

    final facturaData = {
      "tipo": "FACTURA",
      "tipo2": "VENTA",
      "estado": "ACTIVA",
      "fecha_emision": DateTime.now().toIso8601String().split('T').first,
      "id_cliente": cliente?.idCliente,
      "id_medio_pago": medioPago, // ✅ int
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
      // Paso 3: guardar factura (y descontar stock)
      final idFactura = await repo.insertarFactura(facturaData, detalles);

      // Paso 4: preparar datos del adquiriente
      final adquiriente = cliente ??
          Cliente(
            idCliente: -1,
            idTipoDoc: 1, // ✅ dejamos fijo en 1 como pediste
            numeroDocumento: "222222222",
            nombreCompleto: "Consumidor Final",
            razonSocial: "Consumidor Final",
            direccion: "N/A",
            telefono: "N/A",
            correo: "",
          );

      // Paso 5: generar factura DIAN (ahora medioPago es int)
      final pdfData = await PDFService.generarFacturaDIAN(
        numeroFactura: idFactura.toString(),
        fecha: DateTime.now(),
        medioPago: medioPago, // int 1|2|3
        carrito: carrito,
        totalCOP: totalCOP.toDouble(), // double
        ivaTotal: carrito.values
            .map((e) => (e.product.precio * e.qty) * (e.product.ivaPct / 100))
            .fold(0.0, (a, b) => a + b), // double
        nombreEmisor: ref.read(sesionProvider)!.nombreEmpresa,
        nitEmisor: ref.read(sesionProvider)!.nit,            // asegúrate del nombre correcto del provider
        direccionEmisor: ref.read(sesionProvider)!.direccion,
        resolucionDIAN: ref.read(sesionProvider)!.resolucionDian,
        claveTecnica: ref.read(sesionProvider)!.claveTecnica,
        tipoAmbiente: ref.read(sesionProvider)!.tipoAmbiente,
        cliente: adquiriente,
      );


      // Paso 6: enviar correo solo si hay cliente con email
      if (cliente?.correo?.isNotEmpty == true) {
        await EmailService.enviarFactura(
          destinatario: cliente!.correo!,
          nombreDestinatario:
          cliente.nombreCompleto ?? cliente.razonSocial ?? "Cliente",
          pdfBytes: pdfData,
          asunto: "Factura de tu compra en Fashion Line",
        );
      }

      // Paso 7: mostrar/imprimir factura
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
