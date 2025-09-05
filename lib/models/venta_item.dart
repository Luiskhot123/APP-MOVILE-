import 'product.dart';

class VentaItem {
  final Product product;
  int qty;

  VentaItem({
    required this.product,
    this.qty = 1,
  });

  /// Subtotal sin IVA
  double get subtotal => product.precio * qty;

  /// Total con IVA incluido
  double get total => subtotal * (1 + (product.ivaPct / 100));
}

