import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/deudores_repository.dart';

class FacturasDeudorModal extends StatefulWidget {
  final List<Map<String, dynamic>> facturas;
  final String nombreCliente;
  final ScrollController scrollController;

  const FacturasDeudorModal({
    super.key,
    required this.facturas,
    required this.nombreCliente,
    required this.scrollController,
  });

  @override
  State<FacturasDeudorModal> createState() => _FacturasDeudorModalState();
}

class _FacturasDeudorModalState extends State<FacturasDeudorModal> {
  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0);
  final repo = DeudoresRepository();

  Future<void> _mostrarDialogoAbono(Map<String, dynamic> factura) async {
    final TextEditingController controller = TextEditingController();
    double totalFactura =
        (factura['total_factura_cop'] as num?)?.toDouble() ?? 0.0;
    double abonoActual = (factura['abono'] as num?)?.toDouble() ?? 0.0;
    double saldoPendiente = totalFactura - abonoActual;

    await showDialog(
      context: context,
      builder: (context) {
        double valorAbono = 0;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Abonar a factura'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saldo pendiente: ${currencyFormat.format(saldoPendiente)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '¿Cuánto desea abonar?',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    val = val.replaceAll(RegExp(r'[^0-9]'), '');
                    if (val.isEmpty) {
                      controller.text = '';
                      controller.selection =
                      const TextSelection.collapsed(offset: 0);
                      valorAbono = 0;
                      return;
                    }

                    double parsed = double.tryParse(val) ?? 0;
                    if (parsed > saldoPendiente) {
                      parsed = saldoPendiente;
                    }
                    valorAbono = parsed;
                    controller.text = NumberFormat('#,###').format(parsed);
                    controller.selection = TextSelection.collapsed(
                      offset: controller.text.length,
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (valorAbono <= 0) return;
                  final idFactura = factura['id_factura'] as int;
                  final idCliente = factura['id_cliente'] as int? ??
                      (factura['id_cliente'] ?? 0);

                  await repo.registrarAbono(
                    idCliente: idCliente,
                    idFactura: idFactura,
                    abono: valorAbono,
                  );

                  if (mounted) Navigator.pop(context);
                  if (mounted) Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Abono registrado correctamente por ${currencyFormat.format(valorAbono)}',
                      ),
                    ),
                  );
                },
                child: const Text('Confirmar'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 🔹 Encabezado con fondo gris translúcido y borde gris oscuro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              border: Border.all(color: Colors.grey.shade700, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.nombreCliente,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // 🔹 Lista de facturas
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: widget.facturas.length,
              itemBuilder: (context, index) {
                final f = widget.facturas[index];
                final totalFactura =
                    (f['total_factura_cop'] as num?)?.toDouble() ?? 0.0;
                final abono = (f['abono'] as num?)?.toDouble() ?? 0.0;
                final saldoPendiente = totalFactura - abono;
                final subtotal =
                    (f['subtotal'] as num?)?.toDouble() ?? totalFactura * 0.84;
                final iva =
                    (f['iva'] as num?)?.toDouble() ?? totalFactura * 0.16;

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  margin:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        // Plazo del pago arriba a la derecha
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Text(
                            "Plazo del pago: ${f['plazo'] ?? 0} días",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // Contenido de la tarjeta
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Factura #${f['codigo_factura'] ?? ''}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Fecha: ${f['fecha_emision'] ?? ''}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              "Subtotal: ${currencyFormat.format(subtotal)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              "IVA: ${currencyFormat.format(iva)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total deuda inicial: ${currencyFormat.format(totalFactura)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                Text(
                                  "Abono: ${currencyFormat.format(abono)}",
                                  style: const TextStyle(
                                      fontSize: 18, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Saldo restante: ${currencyFormat.format(saldoPendiente)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                ElevatedButton.icon(
                                  onPressed: saldoPendiente <= 0
                                      ? null
                                      : () => _mostrarDialogoAbono(f),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text("Abonar"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
