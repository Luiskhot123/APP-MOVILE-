import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class Deudor {
  final int? id;
  final int idFactura;
  final int idCliente;
  final int plazo; // días
  final double abono;

  Deudor({
    this.id,
    required this.idFactura,
    required this.idCliente,
    required this.plazo,
    required this.abono,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'id_factura': idFactura,
      'id_cliente': idCliente,
      'plazo': plazo,
      'abono': abono,
    };
    if (id != null) m['id'] = id;
    return m;
  }
}

class DeudorCliente {
  final int idCliente;
  final String nombre;
  final String correo;
  final String telefono;
  final String direccion; // 🆕 agregado
  final double totalDeuda;
  final int plazo;
  final double abono;
  final int diasRestantes;

  DeudorCliente({
    required this.idCliente,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.direccion, // 🆕 agregado
    required this.totalDeuda,
    required this.plazo,
    required this.abono,
    required this.diasRestantes,
  });
}

class DeudoresRepository {
  Future<List<DeudorCliente>> obtenerDeudores() async {
    final db = await AppDatabase.instance.database;

    final clientes = await db.query(
      'clientes',
      where: 'deudor = ?',
      whereArgs: [1],
    );

    List<DeudorCliente> lista = [];

    for (final cliente in clientes) {
      final idCliente = cliente['id_cliente'] is int
          ? cliente['id_cliente'] as int
          : int.tryParse(cliente['id_cliente'].toString()) ?? 0;

      final nombre = cliente['nombre_completo']?.toString() ?? '';
      final correo = cliente['correo']?.toString() ?? '';
      final telefono = cliente['telefono']?.toString() ?? '';
      final direccion = cliente['direccion']?.toString() ?? ''; // 🆕 agregado

      final facturas = await db.query(
        'deudores',
        where: 'id_cliente = ?',
        whereArgs: [idCliente],
      );

      double totalDeuda = 0;
      int plazo = 0;
      double abono = 0;

      for (final f in facturas) {
        final idFactura = f['id_factura'] is int
            ? f['id_factura'] as int
            : int.tryParse(f['id_factura'].toString()) ?? 0;

        final plazoFactura = f['plazo'] is int
            ? f['plazo'] as int
            : int.tryParse(f['plazo'].toString()) ?? 0;

        final abonoFactura = f['abono'] is num
            ? (f['abono'] as num).toDouble()
            : double.tryParse(f['abono'].toString()) ?? 0.0;

        plazo = plazoFactura;
        abono += abonoFactura;

        // 🔹 Consultar el total de la factura desde la vista
        final facturaData = await db.query(
          'vista_facturas_totales_ext',
          columns: ['total_factura_cop'],
          where: 'id_factura = ?',
          whereArgs: [idFactura],
        );

        if (facturaData.isNotEmpty) {
          final totalFacturaValue = facturaData.first['total_factura_cop'];
          final totalFactura = totalFacturaValue is num
              ? totalFacturaValue.toDouble()
              : double.tryParse(totalFacturaValue.toString()) ?? 0.0;
          totalDeuda += totalFactura;
        }
      }

      final diasRestantes =
      (plazo - DateTime.now().day % (plazo + 1)).clamp(0, plazo);

      lista.add(DeudorCliente(
        idCliente: idCliente,
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        direccion: direccion, // 🆕 agregado
        totalDeuda: totalDeuda,
        plazo: plazo,
        abono: abono,
        diasRestantes: diasRestantes,
      ));
    }

    return lista;
  }

  Future<int> insertarDeudor(Deudor deudor) async {
    final db = await AppDatabase.instance.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('deudores', deudor.toMap());

      try {
        await txn.update(
          'clientes',
          {'deudor': 1},
          where: 'id_cliente = ?',
          whereArgs: [deudor.idCliente],
        );
      } catch (_) {}
      return id;
    });
  }

  /// 📋 Facturas pendientes de un cliente
  Future<List<Map<String, dynamic>>> getFacturasDeCliente(int idCliente) async {
    final db = await AppDatabase.instance.database;
    final res = await db.rawQuery('''
      SELECT 
        f.id_factura,
        f.id_cliente,
        f.codigo_factura,
        f.fecha_emision,
        f.estado,
        d.plazo,
        d.abono,
        v.total_factura_cop
      FROM facturas f
      INNER JOIN deudores d ON f.id_factura = d.id_factura
      LEFT JOIN vista_facturas_totales_ext v ON f.id_factura = v.id_factura
      WHERE d.id_cliente = ?
      ORDER BY f.fecha_emision DESC
    ''', [idCliente]);
    return res;
  }

  Future<void> deleteDeuda(int idFactura) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'deudores',
      where: 'id_factura = ?',
      whereArgs: [idFactura],
    );
  }

  Future<double> obtenerAbonoActual(int idFactura) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query(
      'deudores',
      columns: ['abono'],
      where: 'id_factura = ?',
      whereArgs: [idFactura],
      limit: 1,
    );
    if (res.isEmpty) return 0.0;
    final val = res.first['abono'];
    return val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> actualizarAbono(int idFactura, double nuevoAbono) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'deudores',
      {'abono': nuevoAbono},
      where: 'id_factura = ?',
      whereArgs: [idFactura],
    );
  }

  /// 💰 Registrar abono acumulado, eliminar factura si se paga completa
  Future<void> registrarAbono({
    required int idCliente,
    required int idFactura,
    required double abono,
  }) async {
    final db = await AppDatabase.instance.database;

    // 🔹 Obtener datos del deudor
    final facturaRes = await db.query(
      'deudores',
      where: 'id_factura = ?',
      whereArgs: [idFactura],
      limit: 1,
    );

    if (facturaRes.isEmpty) throw Exception('Factura no encontrada');
    final factura = facturaRes.first;

    // 🔹 Obtener total real desde la vista de facturas
    final totalRes = await db.query(
      'vista_facturas_totales_ext',
      columns: ['total_factura_cop'],
      where: 'id_factura = ?',
      whereArgs: [idFactura],
      limit: 1,
    );

    final double totalFactura = totalRes.isNotEmpty
        ? (totalRes.first['total_factura_cop'] is num
        ? (totalRes.first['total_factura_cop'] as num).toDouble()
        : double.tryParse(totalRes.first['total_factura_cop'].toString()) ??
        0.0)
        : 0.0;

    final double abonoAcumulado = factura['abono'] is num
        ? (factura['abono'] as num).toDouble()
        : double.tryParse(factura['abono'].toString()) ?? 0.0;

    final double nuevoAbono = abonoAcumulado + abono;

    if (nuevoAbono >= totalFactura) {
      // 🔸 Eliminar factura completamente
      await db.delete(
        'deudores',
        where: 'id_factura = ?',
        whereArgs: [idFactura],
      );

      // 🔹 Revisar si el cliente aún tiene otras facturas pendientes
      final restantes = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM deudores WHERE id_cliente = ?',
        [idCliente],
      ));

      if ((restantes ?? 0) == 0) {
        // 🔸 Marcar cliente como NO deudor
        await db.update(
          'clientes',
          {'deudor': 0},
          where: 'id_cliente = ?',
          whereArgs: [idCliente],
        );
      }
    } else {
      // 🔹 Actualizar abono acumulado
      await db.update(
        'deudores',
        {'abono': nuevoAbono},
        where: 'id_factura = ?',
        whereArgs: [idFactura],
      );
    }
  }
}
