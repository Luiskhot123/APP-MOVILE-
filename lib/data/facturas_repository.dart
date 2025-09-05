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
  Future<int> insertarFactura(Map<String, dynamic> factura, List<Map<String, dynamic>> detalles) async {
    final db = await AppDatabase.instance.database;

    return await db.transaction((txn) async {
      // 1. Insertar factura
      final facturaId = await txn.insert("facturas", factura);

      // 2. Insertar detalles
      for (final d in detalles) {
        final detalle = {
          "id_factura": facturaId,
          "id_producto": d["producto_id"],
          "cantidad": d["cantidad"],
          "precio_unit_base_cop": d["precio_unit_base_cop"],
          "iva_pct": d["iva_pct"] ?? 0.0,
          "retencion_fuente_pct": d["retencion_fuente_pct"] ?? 0.0,
          "otros_impuestos_pct": d["otros_impuestos_pct"] ?? 0.0,
        };
        await txn.insert("detalle_factura", detalle);

        // 3. Actualizar stock
        if (factura["tipo2"] == "COMPRA") {
          await txn.rawUpdate(
            "UPDATE productos SET stock = stock + ? WHERE id_producto = ?",
            [d["cantidad"], d["producto_id"]],
          );
        } else if (factura["tipo2"] == "VENTA") {
          await txn.rawUpdate(
            "UPDATE productos SET stock = stock - ? WHERE id_producto = ?",
            [d["cantidad"], d["producto_id"]],
          );
        }
      }

      return facturaId;
    });
  }
  Future<bool> existeCodigoFactura(String codigo) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      "facturas",
      where: "codigo_factura = ?",
      whereArgs: [codigo],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertFacturaConDetalles({
    required Map<String, dynamic> facturaData,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // 1. Insertar factura
      final idFactura = await txn.insert("facturas", facturaData);

      // 2. Insertar detalles
      for (final det in detalles) {
        await txn.insert("detalle_factura", {
          "id_factura": idFactura,
          "id_producto": det["producto_id"],
          "cantidad": det["cantidad"],
          "precio_unit_base_cop": det["precio"],
          "iva_pct": det["iva"] ?? 0.0,
          "retencion_fuente_pct": det["retencion"] ?? 0.0,
          "otros_impuestos_pct": det["otros"] ?? 0.0,
        });

        // 3. Actualizar stock
        await txn.rawUpdate('''
        UPDATE productos 
        SET stock = stock + ? 
        WHERE id_producto = ?
      ''', [det["cantidad"], det["producto_id"]]);
      }
    });
  }

}
