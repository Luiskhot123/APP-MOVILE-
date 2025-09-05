import 'app_database.dart';

class MediosPagoRepository {
  Future<List<Map<String, dynamic>>> fetchMediosPago() async {
    final db = await AppDatabase.instance.database;
    return await db.query("medios_pago", columns: ["id_medio_pago", "codigo"]);
  }
}
