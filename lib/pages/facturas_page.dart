import 'package:flutter/material.dart';
import '../data/facturas_repository.dart';
import '../data/product_repository.dart';

enum FacturaTab { compras, ventas }

class FacturasPage extends StatefulWidget {
  const FacturasPage({super.key});

  @override
  State<FacturasPage> createState() => _FacturasPageState();
}

class _FacturasPageState extends State<FacturasPage> {
  final _repo = FacturasRepository();
  FacturaTab _tab = FacturaTab.compras;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SegmentButton(
              label: 'Compras',
              selected: _tab == FacturaTab.compras,
              onTap: () => setState(() => _tab = FacturaTab.compras),
            ),
            const SizedBox(width: 12),
            _SegmentButton(
              label: 'Ventas',
              selected: _tab == FacturaTab.ventas,
              onTap: () => setState(() => _tab = FacturaTab.ventas),
            ),
          ],
        ),
        const Divider(height: 24),

        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _repo.fetchFacturas(
              tipo2: _tab == FacturaTab.compras ? "compra" : "venta",
            ),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final facturas = snap.data ?? [];
              if (facturas.isEmpty) {
                return const Center(child: Text('Sin facturas'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: facturas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final f = facturas[i];
                  return ListTile(
                    leading: Icon(
                      _tab == FacturaTab.compras ? Icons.shopping_cart : Icons.sell,
                      color: _tab == FacturaTab.compras ? Colors.green : Colors.orange,
                    ),
                    title: Text("Factura #${f['codigo_factura']}"),
                    subtitle: Text(
                      "Fecha: ${f['fecha_emision']}\nEstado: ${f['estado']}",
                    ),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
