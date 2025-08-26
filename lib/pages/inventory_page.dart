import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

enum StockTab { enStock, agotado }
enum EnStockMenu { todos, bajoStock }

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _repo = ProductRepository();
  StockTab _tab = StockTab.enStock;
  EnStockMenu _menu = EnStockMenu.todos;
  static const int _lowStockThreshold = 5;

  Future<List<Product>> _load() {
    final onlyOut = _tab == StockTab.agotado;
    final isEnStock = _tab == StockTab.enStock;

    return _repo.fetch(
      onlyInStock: isEnStock && _menu == EnStockMenu.todos,
      onlyOutOfStock: onlyOut,
      lowStockThreshold: isEnStock && _menu == EnStockMenu.bajoStock ? _lowStockThreshold : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SegmentButton(
              label: 'En stock',
              selected: _tab == StockTab.enStock,
              onTap: () => setState(() => _tab = StockTab.enStock),
            ),
            const SizedBox(width: 12),
            _SegmentButton(
              label: 'Agotado',
              selected: _tab == StockTab.agotado,
              onTap: () => setState(() => _tab = StockTab.agotado),
            ),
            const SizedBox(width: 12),
            if (_tab == StockTab.enStock)
              PopupMenuButton<EnStockMenu>(
                onSelected: (v) => setState(() => _menu = v),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: EnStockMenu.todos, child: Text('Todos')),
                  PopupMenuItem(value: EnStockMenu.bajoStock, child: Text('Bajo stock')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu, size: 18),
                      const SizedBox(width: 6),
                      Text(_menu == EnStockMenu.todos ? 'Todos' : 'Bajo stock'),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 24),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('Sin productos'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _ProductTile(items[i]),
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

class _ProductTile extends StatelessWidget {
  final Product p;
  const _ProductTile(this.p);

  @override
  Widget build(BuildContext context) {
    final stockStr = (p.stock == null) ? '—' : p.stock.toString();
    final priceStr = _formatCOP(p.precio);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  Text(p.nombre, style: const TextStyle(fontSize: 16)),
                  if (p.categoria != null)
                    Text(p.categoria!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(priceStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Stock: $stockStr'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCOP(double value) => '\$${_thousands(value.toInt())} COP';
  String _thousands(int n) {
    final s = n.toString();
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
    return out.reversed.join();
  }
}

