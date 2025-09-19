import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../models/cliente.dart';
import '../models/venta_item.dart';

class PDFService {
  static Future<Uint8List> generarReciboPOS(
      String codigoFactura,
      DateTime fecha,
      int medioPago,
      Map<String, VentaItem> carrito,
      int totalCOP, {
        Cliente? cliente,
      }) async {
    final pdf = pw.Document();

    final medioPagoTxt = switch (medioPago) {
      1 => "EFECTIVO",
      2 => "TARJETA",
      3 => "TRANSFERENCIA",
      _ => "DESCONOCIDO"
    };

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("RECIBO DE VENTA",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text("Factura: $codigoFactura"),
              pw.Text("Fecha: ${fecha.toIso8601String().split('T').first}"),
              pw.Text("Medio de pago: $medioPagoTxt"),
              if (cliente != null) ...[
                pw.Text("Cliente: ${cliente.nombreCompleto ?? cliente.razonSocial}"),
                pw.Text("Documento: ${cliente.numeroDocumento}"),
              ],
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: ["Producto", "Cant.", "Precio", "Subtotal"],
                data: carrito.values.map((item) {
                  return [
                    item.product.nombre,
                    "${item.qty}",
                    "\$${item.product.precio.toInt()}",
                    "\$${item.subtotal.toInt()}",
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Text("TOTAL: \$${totalCOP.toInt()}",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
