class Product {
  final int id;
  final String nombre;
  final double precio;
  final int? stock;
  final String? categoria;
  final String? imagePath;

  Product({
    required this.id,
    required this.nombre,
    required this.precio,
    this.stock,
    this.categoria,
    this.imagePath,
  });

  static Product fromMap(Map<String, dynamic> m) {
    double _toDouble(dynamic v) =>
        v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

    return Product(
      id: (m['id'] ?? m['id_producto']) as int,
      nombre: (m['nombre'] ?? m['descripcion'] ?? '') as String,
      precio: _toDouble(m['precio'] ?? m['precio_base_cop'] ?? 0),
      stock: m['stock'] == null ? null : (m['stock'] as num).toInt(),
      categoria: m['categoria'] as String?,
      imagePath: m['imagen'] as String?,
    );
  }
}
