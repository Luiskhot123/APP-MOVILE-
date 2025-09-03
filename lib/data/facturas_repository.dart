import 'app_database.dart';

class FacturasRepository {
  Future<List<Map<String, dynamic>>> fetchFacturas({required String tipo2}) async {
    final db = await AppDatabase.instance.database;

    final all = await db.query("facturas");

    final result = await db.query(
      "vista_facturas_totales_ext",
      where: "LOWER(tipo2) = LOWER(?)",
      whereArgs: [tipo2],
      orderBy: "fecha_emision DESC",
    );

    print("FACTURAS ($tipo2): $result");
    return result;
  }
}
