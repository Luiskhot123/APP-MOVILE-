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
  Future<Map<String, dynamic>?> findById(int idEmpresa) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query('empresas', where: 'id_empresa = ?', whereArgs: [idEmpresa], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> actualizarCorreoFacturacion(int empresaId, String correo) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'empresas',
      {'correo_facturacion': correo},
      where: 'id_empresa = ?',
      whereArgs: [empresaId],
    );
  }

  Future<String?> obtenerCorreoFacturacion(int empresaId) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'empresas',
      columns: ['correo_facturacion'],
      where: 'id_empresa = ?',
      whereArgs: [empresaId],
    );
    if (result.isNotEmpty) {
      return result.first['correo_facturacion'] as String?;
    }
    return null;
  }
}
