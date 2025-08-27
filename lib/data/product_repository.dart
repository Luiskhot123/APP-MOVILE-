import 'app_database.dart';
import '../models/product.dart';

class ProductRepository {
  Future<List<Product>> fetch({
    bool onlyInStock = false,
    bool onlyOutOfStock = false,
    int? lowStockThreshold,
  }) async {
    final db = await AppDatabase.instance.database;
    final int threshold = lowStockThreshold ?? 5;
    String where = "1=1";
    List<Object?> whereArgs = [];

    if (onlyInStock) {
      where += " AND stock > 0";
    }
    if (onlyOutOfStock) {
      where += " AND stock = 0";
    }
    if (lowStockThreshold != null) {
      where += " AND stock <= ? AND stock > 0";
      whereArgs.add(lowStockThreshold);
    }

    final result = await db.rawQuery('''
      SELECT p.id_producto, p.nombre, p.descripcion, p.stock, p.precio_base_cop,
             c.nombre AS categoria, u.nombre AS unidad
      FROM productos p
      LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
      LEFT JOIN unidades_medida u ON p.id_unidad = u.id_unidad
      WHERE $where
    ''', whereArgs);

    print("RESULTADOS QUERY: $result"); // 👈 DEBUG

    return result.map((row) => Product.fromMap(row)).toList();
  }

  Future<void> insertProduct(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance.database;
    await db.insert("productos", data);
  }

}
