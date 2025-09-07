import 'package:flutter/material.dart';
import '../data/facturas_repository.dart';
import '../data/product_repository.dart';
import 'crear_proveedor_page.dart';

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
        // Línea que separa el header (Inventario / Facturas) de los botones
        const Divider(height: 1, thickness: 1),

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
                // Si quieres mostrar el botón aun cuando no hay facturas, cambia este return
                return Center(child: Text('Sin facturas'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: facturas.length + 1, // +1 para el botón final
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  if (i == facturas.length) {
                    // Botones finales
                    return Column(
                      children: [
                        // Botón Cargar Factura / Vender
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: () async {
                              if (_tab == FacturaTab.compras) {
                                final result = await Navigator.pushNamed(context, '/cargar_factura');
                                if (result == true) {
                                  setState(() {}); // refresca la lista al volver
                                }
                              } else {
                                // 👉 Aquí llamamos la nueva pantalla de venta
                                final result = await Navigator.pushNamed(context, '/venta');
                                if (result == true) {
                                  setState(() {}); // refresca
                                }
                              }
                            },
                            child: Text(
                              _tab == FacturaTab.compras ? "Cargar Factura" : "Vender",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: () async {
                              if (_tab == FacturaTab.compras) {
                                // 👉 Si estoy en Compras → Crear Proveedor
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CrearProveedorPage()),
                                );
                              } else if (_tab == FacturaTab.ventas) {
                                // 👉 Si estoy en Ventas → Crear Cliente
                                final result = await Navigator.pushNamed(context, '/crear-cliente');
                                if (result == true) {
                                  setState(() {}); // refresca si luego muestras lista de clientes
                                }
                              }
                            },
                            child: Text(
                              _tab == FacturaTab.compras ? "Crear Proveedor" : "Crear Cliente",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                      ],
                    );
                  }


                  final f = facturas[i];

                  // valores desde la vista: total_base_cop, total_iva_cop, total_factura_cop
                  final subtotal = f['total_base_cop'] ?? 0;
                  final iva = f['total_iva_cop'] ?? 0;
                  final total = f['total_factura_cop'] ?? 0;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icono lateral
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _tab == FacturaTab.compras ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _tab == FacturaTab.compras ? Icons.shopping_cart : Icons.label,
                              color: _tab == FacturaTab.compras ? Colors.green : Colors.orange,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Info central
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Factura #${f['codigo_factura'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text("Fecha: ${f['fecha_emision'] ?? ''}", style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text("Subtotal: ${_formatCOP(subtotal)}", style: const TextStyle(fontSize: 13)),
                                Text("IVA: ${_formatCOP(iva)}", style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text("Estado: ${f['estado'] ?? ''}", style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                                )),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Total a la derecha
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatCOP(total),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  String _formatCOP(dynamic value) {
    // acepta int, double, String, null
    int n = 0;
    if (value == null) n = 0;
    else if (value is int) n = value;
    else if (value is double) n = value.toInt();
    else {
      // intentar parsear
      n = int.tryParse(value.toString()) ?? 0;
    }
    return '\$${_thousands(n)} COP';
  }

  String _thousands(int n) {
    final s = n.abs().toString();
    final out = <String>[];
    var count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      out.add(s[i]);
      count++;
      if (count == 3 && i != 0) {
        out.add('.');
        count = 0;
      }
    }
    final sign = n < 0 ? '-' : '';
    return sign + out.reversed.join();
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
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
