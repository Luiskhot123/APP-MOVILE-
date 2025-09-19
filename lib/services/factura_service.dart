import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../data/facturas_repository.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../models/cliente.dart';
import '../models/venta_item.dart';

class FacturaService {
  static Future<void> procesarVenta({
    required BuildContext context,
    required Map<String, VentaItem> carrito,
    required int totalCOP,
    Cliente? cliente,
  }) async {
    // Paso 1: preguntar medio de pago
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
      "id_medio_pago": medioPago,
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
      // Paso 3: guardar factura (también descuenta stock)
      final idFactura = await repo.insertarFactura(facturaData, detalles);

      // Paso 4: generar recibo PDF
      final pdfData = await PDFService.generarReciboPOS(
        idFactura.toString(),
        DateTime.now(),
        medioPago,
        carrito,
        totalCOP,
        cliente: cliente,
      );

      // Paso 5: enviar correo si cliente tiene email
      if (cliente?.correo != null && cliente!.correo!.isNotEmpty) {
        await EmailService.enviarFactura(
          destinatario: cliente.correo!,
          nombreDestinatario:
          cliente.nombreCompleto ?? cliente.razonSocial,
          pdfBytes: pdfData,
          asunto: "Factura de tu compra en Fashion Line",
        );
      }

      // Paso 6: mostrar/imprimir PDF
      await Printing.layoutPdf(onLayout: (format) async => pdfData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Factura registrada con éxito ✅")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
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
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 1), child: const Text("EFECTIVO")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 2), child: const Text("TARJETA")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 3), child: const Text("TRANSFERENCIA")),
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
            onPressed: () => Navigator.pop(ctx, false), // cerrar modal, no cancelar
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

    // Si el usuario eligió cancelar (true), cerramos la página y devolvemos false
    if (salir == true && context.mounted) {
      Navigator.pop(context, false);
    }
  }


}
