import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../models/cliente.dart';
import '../models/venta_item.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:barcode/barcode.dart';
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

  /// Método para generar una **Factura Electrónica con validez DIAN**
  static Future<Uint8List> generarFacturaDIAN({
    required String numeroFactura,
    required DateTime fecha,
    required int medioPago,
    required String nitEmisor,
    required String nombreEmisor,
    required String direccionEmisor,
    required String resolucionDIAN,
    required String claveTecnica,
    required String tipoAmbiente, // 1 = pruebas, 2 = producción
    required Cliente cliente,
    required Map<String, VentaItem> carrito,
    required double totalCOP,
    required double ivaTotal,
    int otrosImpuestos = 0,
  }) async {
    final pdf = pw.Document();

    // -----------------------
    // 1. Generar CUFE (hash SHA-384)
    //    usamos valores sin decimales para formar la cadena (toStringAsFixed(0))
    // -----------------------
    final dataCufe = [
      numeroFactura,
      fecha.toIso8601String().split('T').first,
      fecha.toIso8601String().split('T').last.split('.').first,
      totalCOP.toStringAsFixed(0),
      ivaTotal.toStringAsFixed(0),
      otrosImpuestos.toString(),
      nitEmisor,
      cliente.numeroDocumento,
      claveTecnica,
      tipoAmbiente.toString(),
    ].join('');

    final cufe = sha384.convert(utf8.encode(dataCufe)).toString();

    // -----------------------
    // 2. Generar QR (texto human-friendly + link a DIAN usando el CUFE)
    // -----------------------
    final totalConImpuestos = (totalCOP + ivaTotal + otrosImpuestos).toStringAsFixed(0);

    final qrData = """
Factura: $numeroFactura
Fecha: ${fecha.toIso8601String().split('T').first}
Hora: ${fecha.toIso8601String().split('T').last.split('.').first}
NIT: $nitEmisor
Cliente: ${cliente.numeroDocumento}
Valor: ${totalCOP.toStringAsFixed(0)}
IVA: ${ivaTotal.toStringAsFixed(0)}
Otros Impuestos: $otrosImpuestos
Total: $totalConImpuestos
CUFE: $cufe

https://catalogo-vpfe.dian.gov.co/document/searchqr?documentkey=$cufe
""";

    final qr = Barcode.qrCode();
    final qrSvg = qr.toSvg(qrData, width: 150, height: 150);

    // -----------------------
    // 3. Construir PDF
    // -----------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado empresa
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(nombreEmisor,
                            style: pw.TextStyle(
                                fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text("NIT: $nitEmisor"),
                        pw.Text("Dirección: $direccionEmisor"),
                      ]),
                  pw.Column(children: [
                    pw.Text("Factura Electrónica de Venta",
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(numeroFactura,
                        style: pw.TextStyle(fontSize: 14)),
                  ])
                ],
              ),
              pw.SizedBox(height: 20),

              // Datos cliente
              pw.Text("Cliente: ${cliente.nombreCompleto ?? cliente.razonSocial}"),
              pw.Text("Documento: ${cliente.numeroDocumento}"),
              pw.SizedBox(height: 10),

              // Tabla de productos
              pw.Table.fromTextArray(
                headers: ["Código", "Descripción", "Cant.", "Vr Unit.", "%IVA", "Subtotal"],
                data: carrito.values.map((item) {
                  final subtotal = item.subtotal.toInt();
                  final iva = (item.product.ivaPct ?? 0);
                  return [
                    item.product.codigoBarras ?? "",
                    item.product.nombre,
                    "${item.qty}",
                    "\$${item.product.precio.toInt()}",
                    "$iva%",
                    "\$${subtotal.toInt()}",
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),

              // Totales
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Subtotal: \$${totalCOP - ivaTotal}"),
                        pw.Text("IVA: \$${ivaTotal}"),
                        pw.Text("Otros impuestos: \$${otrosImpuestos}"),
                        pw.Text(
                            "TOTAL: \$${totalCOP + ivaTotal + otrosImpuestos}",
                            style: pw.TextStyle(
                                fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ])
                ],
              ),
              pw.SizedBox(height: 20),

              // CUFE
              pw.Text("CUFE: $cufe",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),

              pw.SizedBox(height: 20),

              // QR
              pw.Center(
                child: pw.SvgImage(svg: qrSvg, width: 120, height: 120),
              ),

              pw.SizedBox(height: 20),

              // Resolución DIAN
              pw.Text("Resolución DIAN: $resolucionDIAN",
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

}
