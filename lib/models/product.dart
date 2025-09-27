class Product {
  final int id;
  final String nombre;
  final String? descripcion;
  final int stock;
  final double precio;
  final double ivaPct;
  final String? categoria;
  final String? unidad;
  final int bajoStock;
  final String? sku;
  final String? codigoBarras;
  final double otrosImpuestosPct;


  Product({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.stock,
    required this.precio,
    required this.ivaPct,
    this.categoria,
    this.unidad,
    required this.bajoStock,
    this.sku,
    this.codigoBarras,
    required this.otrosImpuestosPct,
  });

  factory Product.fromMap(Map<String, dynamic> json) => Product(
    id: json['id_producto'],
    nombre: json['nombre'],
    descripcion: json['descripcion'],
    stock: json['stock'] ?? 0,
    precio: (json['precio_base_cop'] as num).toDouble(),
    ivaPct: (json['iva_pct'] ?? 0).toDouble(), // 👈 mapea el iva
    categoria: json['categoria'],   // viene del JOIN
    unidad: json['unidad'],         // viene del JOIN
    bajoStock: json['bajo_stock'] != null ? json['bajo_stock'] as int : 5, // 👈 default
    sku: json['sku'], // 👈 mapea
    codigoBarras: json['codigo_barras'], // 👈 mapea
    otrosImpuestosPct: (json['otros_impuestos_pct'] ?? 0).toDouble(), // 👈 mapea el iva
  );
}
