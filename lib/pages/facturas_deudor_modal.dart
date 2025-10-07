import 'package:flutter/material.dart';

class FacturasDeudorModal extends StatelessWidget {
  final List<Map<String, dynamic>> facturas;
  final String nombreCliente;
  final ScrollController scrollController;

  const FacturasDeudorModal({
    super.key,
    required this.facturas,
    required this.nombreCliente,
    required this.scrollController,
  });

  String _formatCOP(dynamic valor) {
    if (valor == null) return '\$0';
    final num number = valor is num ? valor : num.tryParse(valor.toString()) ?? 0;
    return '\$${number.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            'Facturas de $nombreCliente',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: facturas.length,
              itemBuilder: (context, i) {
                final f = facturas[i];

                // valores desde la vista y la tabla deudores
                final subtotal = f['total_base_cop'] ?? 0;
                final iva = f['total_iva_cop'] ?? 0;
                final total = f['total_factura_cop'] ?? 0;
                final plazo = f['plazo'] ?? 0;

                final vencida = plazo <= 0;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: vencida ? Colors.red : Colors.grey.shade300,
                      width: vencida ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Factura #${f['codigo_factura'] ?? ''}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text("Fecha emisión: ${f['fecha_emision'] ?? ''}",
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Text("Subtotal: ${_formatCOP(subtotal)}",
                                style: const TextStyle(fontSize: 13)),
                            Text("IVA: ${_formatCOP(iva)}",
                                style: const TextStyle(fontSize: 13)),
                            Text("Total: ${_formatCOP(total)}",
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              "Plazo restante: ${plazo} días",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: vencida ? Colors.red : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Estado: ${f['estado'] ?? ''}",
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
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
