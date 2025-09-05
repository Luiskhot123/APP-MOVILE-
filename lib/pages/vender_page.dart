import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../models/venta_item.dart';
import 'package:audioplayers/audioplayers.dart';


class VenderPage extends StatefulWidget {
  const VenderPage({super.key});

  @override
  State<VenderPage> createState() => _VenderPageState();
}

class _VenderPageState extends State<VenderPage> {
  final _player = AudioPlayer();
  final _repo = ProductRepository();
  final Map<String, VentaItem> _carrito = {}; // key: codigo_barras

  String? _lastCode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preguntarFacturaElectronica());
  }

  Future<void> _preguntarFacturaElectronica() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('¿Desea factura electrónica?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
    // Por ahora, independientemente de la elección, seguimos en esta pantalla.
  }

  Future<void> _onScan(String code) async {
    final now = DateTime.now();
    // Evitar duplicados muy seguidos
    if (_lastCode == code && _lastScanAt != null && now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastCode = code;
    _lastScanAt = now;

    // 👇 Aquí hacemos sonar el pip ANTES de buscar en DB
    await _player.play(AssetSource('sounds/beep.mp3'));

    final prod = await _repo.findByBarcode(code);
    if (!mounted) return;

    if (prod == null) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Producto no encontrado'),
          content: Text('El código "$code" no existe en la base de datos.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar')),
          ],
        ),
      );
      return;
    }

    setState(() {
      if (_carrito.containsKey(code)) {
        _carrito[code]!.qty++;
      } else {
        _carrito[code] = VentaItem(product: prod, qty: 1);
      }
    });
  }

  void _increment(String code) {
    setState(() => _carrito[code]!.qty++);
  }

  void _decrement(String code) {
    setState(() {
      final item = _carrito[code]!;
      if (item.qty > 1) {
        item.qty--;
      } else {
        // Si baja de 1, opcionalmente preguntar si elimina:
        _confirmarEliminar(code);
      }
    });
  }

  Future<void> _confirmarEliminar(String code) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar el producto de la venta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Conservar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _carrito.remove(code));
    }
  }

  Future<void> _confirmarCancelarVenta() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desea cancelar la venta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Regresar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar')),
        ],
      ),
    );
    if (salir == true && mounted) {
      Navigator.pop(context, false); // volvemos a facturas_page
    }
  }

  int get _totalCOP {
    double t = 0;
    for (final v in _carrito.values) {
      t += v.total;
    }
    return t.toInt();
  }

  @override
  Widget build(BuildContext context) {
    // Mitad superior => cámara; mitad inferior => lista
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venta'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Cámara (mitad de la pantalla)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: MobileScanner(
                fit: BoxFit.cover,
                onDetect: (capture) {
                  for (final b in capture.barcodes) {
                    final code = b.rawValue;
                    if (code != null && code.isNotEmpty) {
                      _onScan(code);
                    }
                  }
                },
              ),
            ),
          ),

          // Lista de productos escaneados
          Expanded(
            child: _carrito.isEmpty
                ? const Center(child: Text('Escanee productos para agregar a la venta'))
                : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ..._carrito.entries.map((e) => _VentaItemTile(
                  code: e.key,
                  item: e.value,
                  onInc: () => _increment(e.key),
                  onDec: () => _decrement(e.key),
                  onRemove: () => _confirmarEliminar(e.key),
                )),
                const SizedBox(height: 12),
                _TotalBar(total: _formatCOP(_totalCOP)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _confirmarCancelarVenta,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // TODO: guardar venta en DB, emitir factura, etc.
                          // Por ahora sólo volvemos:
                          Navigator.pop(context, true);
                        },
                        child: const Text('Vender'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCOP(int n) => '\$${_thousands(n)} COP';
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

class _VentaItemTile extends StatelessWidget {
  final String code;
  final VentaItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _VentaItemTile({
    required this.code,
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = item.product;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Imagen
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _ProductImagePlaceholder(product: p),
              ),

              const SizedBox(width: 12),

              // Descripción + precios
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    if (p.categoria != null)
                      Text(p.categoria!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Precio base: ${_formatCOP(p.precio.toInt())}'),
                    Text('IVA: ${p.ivaPct.toStringAsFixed(0)}%'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                            onPressed: onDec,
                            icon: const Icon(Icons.remove_circle_outline)),
                        Text('${item.qty}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                            onPressed: onInc,
                            icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Totales
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ✅ Total con IVA
                  Text(
                    _formatCOP(item.total.toInt()),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // ✅ Subtotal sin IVA
                  Text(
                    'Subtotal: ${_formatCOP(item.subtotal.toInt())}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Botón X
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCOP(int n) {
    final s = n.abs().toString();
    final out = <String>[];
    var c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      out.add(s[i]);
      c++;
      if (c == 3 && i != 0) {
        out.add('.');
        c = 0;
      }
    }
    return '\$${out.reversed.join()} COP';
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  final Product product;
  const _ProductImagePlaceholder({required this.product});

  @override
  Widget build(BuildContext context) {
    // Si tu Product tiene algo como product.fotoPath, úsalo aquí:
    final String? path = null; // p.ej. product.fotoPath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(path), fit: BoxFit.cover),
      );
    }
    return const Icon(Icons.image, size: 30);
  }
}

class _TotalBar extends StatelessWidget {
  final String total;
  const _TotalBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long),
          const SizedBox(width: 8),
          const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(total, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
