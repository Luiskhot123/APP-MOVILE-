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
    final totalConImpuestos = (totalCOP).toStringAsFixed(0);

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
          const int maxRows = 40;
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
// 💰 Sección inferior: Totales y pagos organizados
// -----------------------
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // -------------------
                  // Columna izquierda
                  // -------------------
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 1️⃣ Total líneas + Valor en letras
                      pw.Container(
                        constraints: const pw.BoxConstraints(maxWidth: 300), // ancho máximo similar a columna descripción
                        child: pw.Table(
                          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                          columnWidths: const {
                            0: pw.IntrinsicColumnWidth(),
                            1: pw.FlexColumnWidth(),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: PdfColors.grey300,
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    "Total líneas",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text("${carrito.length}", style: const pw.TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: PdfColors.grey300,
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    "Valor en letras",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    convertirNumeroALetras(subtotal + ivaTotal + otrosImpuestos),
                                    style: const pw.TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 10),

                      // 2️⃣ Forma / Medio de pago
                      pw.Container(
                        constraints: const pw.BoxConstraints(maxWidth: 180), // mismo ancho que tabla superior
                        child: pw.Table(
                          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                          columnWidths: const {
                            0: pw.IntrinsicColumnWidth(),
                            1: pw.FlexColumnWidth(),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: PdfColors.grey300,
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    "Forma de pago",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(formaPagoTxt, style: const pw.TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: PdfColors.grey300,
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    "Medio de pago",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(medioPagoTxt, style: const pw.TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(width: 70), // espacio entre columnas

                  // -------------------
                  // Columna derecha: Totales
                  // -------------------
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
                      columnWidths: const {
                        0: pw.IntrinsicColumnWidth(),
                        1: pw.FlexColumnWidth(),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Container(
                              color: PdfColors.grey300,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("Subtotal", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("\$${subtotal.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Container(
                              color: PdfColors.grey300,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("IVA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("\$${ivaTotal.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Container(
                              color: PdfColors.grey300,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("Otros impuestos", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("\$${otrosImpuestos.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Container(
                              color: PdfColors.grey300,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text("\$${(subtotal + ivaTotal + otrosImpuestos).toStringAsFixed(0)}",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              pw.Text("CUFE: $cufe",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),

              pw.SizedBox(height: 8),

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

  static String convertirNumeroALetras(double monto) {
    final unidades = [
      "",
      "uno",
      "dos",
      "tres",
      "cuatro",
      "cinco",
      "seis",
      "siete",
      "ocho",
      "nueve"
    ];

    final especiales = [
      "diez",
      "once",
      "doce",
      "trece",
      "catorce",
      "quince",
      "dieciséis",
      "diecisiete",
      "dieciocho",
      "diecinueve"
    ];

    final decenas = [
      "",
      "",
      "veinte",
      "treinta",
      "cuarenta",
      "cincuenta",
      "sesenta",
      "setenta",
      "ochenta",
      "noventa"
    ];

    final centenas = [
      "",
      "ciento",
      "doscientos",
      "trescientos",
      "cuatrocientos",
      "quinientos",
      "seiscientos",
      "setecientos",
      "ochocientos",
      "novecientos"
    ];

    String convertirParte(int numero) {
      if (numero == 0) return "cero";
      if (numero == 100) return "cien";

      final c = numero ~/ 100;
      final d = (numero % 100) ~/ 10;
      final u = numero % 10;
      final n = numero % 100;

      String resultado = "";

      if (c > 0) resultado += "${centenas[c]} ";

      if (n > 0) {
        if (n < 10) {
          resultado += unidades[u];
        } else if (n >= 10 && n < 20) {
          resultado += especiales[n - 10];
        } else {
          if (d == 2 && u != 0) {
            resultado += "veinti${unidades[u]}";
          } else {
            resultado += decenas[d];
            if (u != 0) resultado += " y ${unidades[u]}";
          }
        }
      }

      return resultado.trim();
    }

    // Separar miles
    int entero = monto.floor();
    int miles = entero ~/ 1000;
    int resto = entero % 1000;

    String resultado = "";
    if (miles > 0) {
      if (miles == 1) {
        resultado += "mil ";
      } else {
        resultado += "${convertirParte(miles)} mil ";
      }
    }

    if (resto > 0) {
      resultado += "${convertirParte(resto)} ";
    }

    resultado = resultado.trim();

    // Agregar "pesos colombianos"
    resultado = "${resultado.isEmpty ? "cero" : resultado} pesos colombianos";

    return resultado;
  }






}
