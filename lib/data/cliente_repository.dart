import 'package:sqflite/sqflite.dart';
import '../models/cliente.dart';
import 'app_database.dart';

class ClienteRepository {
  Future<Cliente?> findByTipoYDocumento(int tipo, String numero) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'clientes',
      where: 'id_tipo_doc = ? AND numero_documento = ?',
      whereArgs: [tipo, numero],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Cliente.fromMap(res.first);
    }
    return null;
  }
}
