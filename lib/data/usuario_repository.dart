import 'app_database.dart';

class UsuarioRepository {
  Future<Map<String, dynamic>?> autenticar({
    required int idEmpresa,
    required String usuario,
    required String contrasena,
  }) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      "usuarios",
      where: "id_empresa = ? AND usuario = ? AND contrasena = ?",
      whereArgs: [idEmpresa, usuario, contrasena],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
  Future<List<Map<String, dynamic>>> fetchUsuariosPorEmpresa(int idEmpresa) async {
    final db = await AppDatabase.instance.database;
    return await db.query(
      "usuarios",
      where: "id_empresa = ?",
      whereArgs: [idEmpresa],
      orderBy: "nombre_completo ASC",
    );
  }
}
