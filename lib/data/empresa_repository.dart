import 'app_database.dart';

class EmpresaRepository {
  Future<List<Map<String, dynamic>>> fetchEmpresas() async {
    final db = await AppDatabase.instance.database;
    return await db.query("empresas", orderBy: "nombre ASC");
  }

  Future<Map<String, dynamic>?> findByNombre(String nombre) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      "empresas",
      where: "LOWER(nombre) = LOWER(?)",
      whereArgs: [nombre],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}
