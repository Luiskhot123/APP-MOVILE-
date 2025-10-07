import 'package:sqflite/sqflite.dart';

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
  Future<int> insertarFactura(
      Map<String, dynamic> factura,
      List<Map<String, dynamic>> detalles,
      ) async {
    final db = await AppDatabase.instance.database;

    return await db.transaction((txn) async {
      // 1️⃣ Generar un código temporal único para cumplir con NOT NULL
      final tempCodigo = "TMP-${DateTime.now().millisecondsSinceEpoch}";

      final facturaData = Map<String, dynamic>.from(factura);
      facturaData["codigo_factura"] = tempCodigo;

      // 🔸 Si no trae forma de pago, por defecto será contado (1)
      facturaData["forma_pago_id"] = factura["forma_pago_id"] ?? 1;

      // 2️⃣ Insertar factura
      final facturaId = await txn.insert("facturas", facturaData);

      // 3️⃣ Generar código definitivo con ceros a la izquierda
      final codigoFactura = "FAC-${facturaId.toString().padLeft(4, '0')}";

      await txn.update(
        "facturas",
        {"codigo_factura": codigoFactura},
        where: "id_factura = ?",
        whereArgs: [facturaId],
      );

      // 4️⃣ Insertar detalles de factura
      for (final d in detalles) {
        await txn.insert("detalle_factura", {
          "id_factura": facturaId,
          "id_producto": d["producto_id"],
          "cantidad": d["cantidad"],
          "precio_unit_base_cop": d["precio_unit_base_cop"],
          "iva_pct": d["iva_pct"] ?? 0.0,
          "retencion_fuente_pct": d["retencion_fuente_pct"] ?? 0.0,
          "otros_impuestos_pct": d["otros_impuestos_pct"] ?? 0.0,
        });

        // 5️⃣ Actualizar stock según tipo
        if (factura["tipo2"] == "VENTA") {
          await txn.rawUpdate(
            "UPDATE productos SET stock = stock - ? WHERE id_producto = ?",
            [d["cantidad"], d["producto_id"]],
          );
        } else if (factura["tipo2"] == "COMPRA") {
          await txn.rawUpdate(
            "UPDATE productos SET stock = stock + ? WHERE id_producto = ?",
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

  Future<Map<String, int>> obtenerEstadisticas(String tipo2) async {
    // tipo2 = "COMPRA" o "VENTA"
    final db = await AppDatabase.instance.database;

    final hoy = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM facturas WHERE tipo2 = ? AND DATE(fecha_emision) = DATE('now')",
        [tipo2],
      ),
    ) ?? 0;

    final semana = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM facturas WHERE tipo2 = ? AND strftime('%W', fecha_emision) = strftime('%W', 'now')",
        [tipo2],
      ),
    ) ?? 0;

    final mes = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM facturas WHERE tipo2 = ? AND strftime('%m', fecha_emision) = strftime('%m', 'now')",
        [tipo2],
      ),
    ) ?? 0;

    return {
      "Hoy": hoy,
      "Esta semana": semana,
      "Este mes": mes,
    };
  }


}
