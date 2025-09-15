import 'package:flutter/cupertino.dart';

import 'app_database.dart';

class VinculacionRepository {

  /// Devuelve la fila si existe y es válida (no usada y no expirada), o null.
  Future<Map<String, dynamic>?> validateCode(String code) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'vinculacion_codes',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final row = res.first;
    final used = (row['used'] ?? 0) as int;
    if (used == 1) return null;

    final expiresAt = row['expires_at'];
    if (expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final exp = (expiresAt is int) ? expiresAt : int.tryParse(expiresAt.toString()) ?? 0;
      if (exp > 0 && now > exp) return null;
    }

    return row;
  }

  Future<int> insertarCodigo({
    required String codigo,
    required int idEmpresa,
    required int rol,
    int? expiresAtMillis, // opcional: si no se manda, se calcula 7 días
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final expiresAt = expiresAtMillis ??
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

    return await db.insert('vinculacion_codes', {
      'code': codigo,
      'id_empresa': idEmpresa,
      'rol': rol,
      'created_at': now,
      'expires_at': expiresAt,
      'used': 0, // 0 = no usado, 1 = usado
    });
  }



  String generarCodigo(int idEmpresa, int rol) {
    final empresaPart = idEmpresa.toString().padLeft(10, '0');
    final rolPart = rol.toString();
    final randomPart = List.generate(9, (_) => (0 + (DateTime.now().microsecondsSinceEpoch % 10)).toString()).join();
    return empresaPart + rolPart + randomPart;
  }

  Future<List<Map<String, dynamic>>> obtenerCodigosActivos(int idEmpresa) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'vinculacion_codes',
      where: 'id_empresa = ? AND used = 0 AND expires_at > ?',
      whereArgs: [idEmpresa, now],
      orderBy: 'created_at DESC',
    );
    // DEBUG
    debugPrint('VincRepo.obtenerCodigosActivos -> company=$idEmpresa found=${rows.length}');
    for (final r in rows) {
      debugPrint('  code=${r['code']} used=${r['used']} expires=${r['expires_at']} created=${r['created_at']}');
    }
    return rows;
  }


  Future<int> marcarCodigoUsado(String codigo) async {
    final db = await AppDatabase.instance.database;
    return await db.update(
      'vinculacion_codes',
      {'used': 1},
      where: 'code = ?',
      whereArgs: [codigo],
    );
  }

  Future<int> markUsed(String code) async {
    final db = await AppDatabase.instance.database;
    return await db.update('vinculacion_codes', {'used': 1}, where: 'code = ?', whereArgs: [code]);
  }
}
