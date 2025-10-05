import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../models/cliente.dart';
import '../models/venta_item.dart';
import 'package:pdf/pdf.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:barcode/barcode.dart';

class PDFService {
  static Future<Uint8List> generarReciboPOS(
      String codigoFactura,
      DateTime fecha,
      int medioPago,
      int formaPago,
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

    final formaPagoTxt = switch (formaPago) {
      1 => "CONTADO",
      2 => "CRÉDITO",
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
              pw.SizedBox(height: 10),

              // 👇 Nueva sección inferior izquierda
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Forma de pago: $formaPagoTxt",
                          style: pw.TextStyle(fontSize: 12)),
                      pw.Text("Medio de pago: $medioPagoTxt",
                          style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // CUFE o datos adicionales
              pw.Text("CUFE / Código único (si aplica):",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
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
    required int formaPago,
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

    final formaPagoTxt = switch (formaPago) {
      1 => "CONTADO",
      2 => "CRÉDITO",
      _ => "DESCONOCIDO"
    };

    final medioPagoTxt = switch (medioPago) {
      1 => "EFECTIVO",
      2 => "TARJETA",
      3 => "TRANSFERENCIA",
      _ => "DESCONOCIDO"
    };

    final tipoDocTxt = switch (cliente.idTipoDoc) {
      1 => "CC",
      2 => "NIT",
      3 => "CE",
      _ => "N/D",
    };

    // -----------------------
    // 1️⃣ Generar CUFE
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
    // 2️⃣ Generar QR
    // -----------------------
    final totalConImpuestos = (totalCOP + ivaTotal + otrosImpuestos).toStringAsFixed(0);

    final qrData = """
Factura: $numeroFactura
Fecha: ${fecha.toIso8601String().split('T').first}
Hora: ${fecha.toIso8601String().split('T').last.split('.').first}
NIT: $nitEmisor
Cliente: ${cliente.numeroDocumento}
Forma de pago: $formaPagoTxt
Medio de pago: $medioPagoTxt
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
    // 3️⃣ Construir PDF
    // -----------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 15, 20, 10),
        build: (context) {
          const int maxRows = 60;
          final int emptyRows = (maxRows - carrito.length).clamp(0, maxRows);
          final subtotal = totalCOP - ivaTotal;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🧾 ENCABEZADO EMPRESA
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
                    ],
                  ),
                  pw.Column(children: [
                    pw.Text("Factura Electrónica de Venta",
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(numeroFactura,
                        style: const pw.TextStyle(fontSize: 14)),
                  ]),
                ],
              ),

              pw.SizedBox(height: 12),

              // 📄 TABLAS LADO A LADO: Cliente (izquierda) y Fecha de emisión (derecha)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 1️⃣ Tabla cliente (izquierda)
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: pw.IntrinsicColumnWidth(),
                      1: pw.IntrinsicColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Cliente",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(cliente.nombreCompleto ?? cliente.razonSocial ?? ""),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Dirección",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(cliente.direccion ?? ""),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Tipo de identificación",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(tipoDocTxt),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("No. Identificación",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(cliente.numeroDocumento),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(width: 150), // ✅ Espacio entre tablas

                  // 2️⃣ Tabla fecha de emisión (derecha)
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: const {0: pw.IntrinsicColumnWidth()},
                    children: [
                      // Encabezado gris
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Fecha Generación Factura",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      // Fila con fecha centrada
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Center(
                              child: pw.Text(
                                fecha.toIso8601String().split('T').first,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),





              pw.SizedBox(height: 10),

              // 🧩 TABLA DE PRODUCTOS
              pw.Table(
                border: pw.TableBorder(
                  top: const pw.BorderSide(width: 0.5, color: PdfColors.grey700),
                  bottom: const pw.BorderSide(width: 0.5, color: PdfColors.grey700),
                  left: const pw.BorderSide(width: 0.5, color: PdfColors.grey700),
                  right: const pw.BorderSide(width: 0.5, color: PdfColors.grey700),
                  horizontalInside: pw.BorderSide.none,
                  verticalInside:
                  const pw.BorderSide(width: 0.5, color: PdfColors.grey700),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // 🏷️ ENCABEZADOS
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _headerCell("Código"),
                      _headerCell("Descripción"),
                      _headerCell("Cant."),
                      _headerCell("Vr Unit."),
                      _headerCell("%IVA"),
                      _headerCell("Subtotal"),
                    ],
                  ),

                  // 📦 FILAS DE PRODUCTOS
                  ...carrito.values.map((item) {
                    final subtotalItem = item.subtotal.toInt();
                    final iva = (item.product.ivaPct ?? 0);
                    return pw.TableRow(
                      children: [
                        _cell(item.product.codigoBarras ?? ""),
                        _cell(item.product.nombre),
                        _cell("${item.qty}"),
                        _cell("\$${item.product.precio.toInt()}"),
                        _cell("$iva%"),
                        _cell("\$${subtotalItem.toInt()}"),
                      ],
                    );
                  }),

                  // 🔲 FILAS VACÍAS (HASTA 60)
                  ...List.generate(emptyRows, (index) {
                    return pw.TableRow(
                      children: List.generate(6, (_) => _cell("")),
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 10),

              // -----------------------
// 💰 Sección inferior: Totales y pagos
// -----------------------
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 1️⃣ Total de líneas y valor en letras (izquierda arriba)
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: const {0: pw.IntrinsicColumnWidth()},
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Total de líneas y valor en letras",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Líneas: ${carrito.length}", style: const pw.TextStyle(fontSize: 10)),
                                pw.Text("Valor en letras: ${convertirNumeroALetras(totalCOP + ivaTotal + otrosImpuestos)}",
                                    style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(width: 20), // Espacio entre tablas

                  // 2️⃣ Forma de pago y medio de pago (centro-izquierda)
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: const {0: pw.IntrinsicColumnWidth()},
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Forma / Medio de pago",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Forma de pago: $formaPagoTxt", style: const pw.TextStyle(fontSize: 10)),
                                pw.Text("Medio de pago: $medioPagoTxt", style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(width: 20), // Espacio entre tablas

                  // 3️⃣ Totales (derecha)
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    columnWidths: const {0: pw.IntrinsicColumnWidth()},
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: PdfColors.grey300,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Totales",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Subtotal: \$${subtotal.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                                pw.Text("IVA: \$${ivaTotal.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                                pw.Text("Otros impuestos: \$${otrosImpuestos.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                                pw.Text(
                                  "TOTAL: \$${(subtotal + ivaTotal + otrosImpuestos).toStringAsFixed(0)}",
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),


              pw.SizedBox(height: 10),

              pw.Text("CUFE: $cufe",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),

              pw.SizedBox(height: 15),

              pw.Center(child: pw.SvgImage(svg: qrSvg, width: 120, height: 120)),

              pw.Spacer(),

              pw.Text("Resolución DIAN: $resolucionDIAN",
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }


// --------------------------
// 📦 Helpers
// --------------------------
  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black)),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  static String convertirNumeroALetras(double numero) {
    final List<String> unidades = [
      'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'
    ];
    final List<String> decenas = [
      'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve'
    ];
    final List<String> decenasMultiples = [
      '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'
    ];
    final List<String> centenas = [
      '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'
    ];

    String convertirParteEntera(int numero) {
      if (numero == 0) return 'cero';
      if (numero == 100) return 'cien';
      if (numero < 10) return unidades[numero];
      if (numero < 20) return decenas[numero - 10];
      if (numero < 100) {
        int decena = numero ~/ 10;
        int unidad = numero % 10;
        return '${decenasMultiples[decena]}${unidad > 0 ? ' y ${unidades[unidad]}' : ''}';
      }
      if (numero < 1000) {
        int centena = numero ~/ 100;
        int resto = numero % 100;
        return '${centenas[centena]}${resto > 0 ? ' ${convertirParteEntera(resto)}' : ''}';
      }
      return '';
    }

    String convertirParteDecimal(int numero) {
      if (numero == 0) return '';
      return ' con ${convertirParteEntera(numero)}';
    }

    int parteEntera = numero.toInt();
    int parteDecimal = ((numero - parteEntera) * 100).toInt();

    String enteroEnLetras = convertirParteEntera(parteEntera);
    String decimalEnLetras = convertirParteDecimal(parteDecimal);

    return '$enteroEnLetras$decimalEnLetras pesos';
  }





}
