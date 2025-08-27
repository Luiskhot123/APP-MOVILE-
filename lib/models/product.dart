class Product {
  final int id;
  final String nombre;
  final String? descripcion;
  final int stock;
  final double precio;
  final String? categoria;
  final String? unidad;

  Product({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.stock,
    required this.precio,
    this.categoria,
    this.unidad,
  });

  factory Product.fromMap(Map<String, dynamic> json) => Product(
    id: json['id_producto'],
    nombre: json['nombre'],
    descripcion: json['descripcion'],
    stock: json['stock'] ?? 0,
    precio: (json['precio_base_cop'] as num).toDouble(),
    categoria: json['categoria'],   // viene del JOIN
    unidad: json['unidad'],         // viene del JOIN
  );
}
