import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import 'app_database.dart';

class ProductRepository {
  Future<List<Product>> fetch({
    bool onlyInStock = false,
    bool onlyOutOfStock = false,
    int? lowStockThreshold,
  }) async {
    final Database db = await AppDatabase.instance.database;

    List<Map<String, dynamic>> rows = [];
    try {
      // Esquema “completo”: productos + categorias + stock
      rows = await db.rawQuery('''
      SELECT p.id AS id, p.nombre, p.precio, p.stock,
             c.nombre AS categoria
      FROM productos p
      LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
      ORDER BY p.nombre COLLATE NOCASE;
      ''');
    } on DatabaseException {
      try {
        // Esquema simple: id, nombre, precio (sin stock ni categoria)
        rows = await db.rawQuery('''
        SELECT id AS id, nombre, precio, NULL AS stock, NULL AS categoria
        FROM productos
        ORDER BY nombre COLLATE NOCASE;
        ''');
      } on DatabaseException {
        // Alternativa: otras columnas comunes
        rows = await db.rawQuery('''
        SELECT id_producto AS id, nombre, precio_base_cop AS precio, stock, NULL AS categoria
        FROM productos
        ORDER BY nombre COLLATE NOCASE;
        ''');
      }
    }

    var list = rows.map(Product.fromMap).toList();

    if (onlyInStock) {
      list = list.where((p) => (p.stock ?? 0) > 0).toList();
    } else if (onlyOutOfStock) {
      list = list.where((p) => (p.stock ?? 0) == 0).toList();
    }

    if (lowStockThreshold != null) {
      list = list.where((p) => (p.stock ?? 0) > 0 && (p.stock ?? 0) <= lowStockThreshold).toList();
    }

    return list;
  }
}
