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
  final double totalDeuda;
  final int plazo;
  final double abono;
  final int diasRestantes;

  DeudorCliente({
    required this.idCliente,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.totalDeuda,
    required this.plazo,
    required this.abono,
    required this.diasRestantes,
  });
}

class DeudoresRepository {
  Future<List<DeudorCliente>> obtenerDeudores() async {
    final db = await AppDatabase.instance.database;

    // Obtener clientes con deudor = 1
    final clientes = await db.query('clientes', where: 'deudor = ?', whereArgs: [1]);

    List<DeudorCliente> lista = [];

    for (final cliente in clientes) {
      final idCliente = cliente['id_cliente'] is int
          ? cliente['id_cliente'] as int
          : int.tryParse(cliente['id_cliente'].toString()) ?? 0;

      final nombre = cliente['nombre_completo']?.toString() ?? '';
      final correo = cliente['correo']?.toString() ?? '';
      final telefono = cliente['telefono']?.toString() ?? '';

      // Obtener facturas morosas
      final facturas = await db.query(
        'deudores',
        where: 'id_cliente = ?',
        whereArgs: [idCliente],
      );

      double totalDeuda = 0;
      int plazo = 0;
      double abono = 0;

      for (final f in facturas) {
        // id_factura
        final idFactura = f['id_factura'] is int
            ? f['id_factura'] as int
            : int.tryParse(f['id_factura'].toString()) ?? 0;

        // plazo
        final plazoFactura = f['plazo'] is int
            ? f['plazo'] as int
            : int.tryParse(f['plazo'].toString()) ?? 0;

        // abono
        final abonoFactura = f['abono'] is num
            ? (f['abono'] as num).toDouble()
            : double.tryParse(f['abono'].toString()) ?? 0.0;

        plazo = plazoFactura;
        abono += abonoFactura;

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

      // 🔸 Simulación simple de días restantes
      final diasRestantes = (plazo - DateTime.now().day % (plazo + 1)).clamp(0, plazo);

      lista.add(DeudorCliente(
        idCliente: idCliente,
        nombre: nombre,
        correo: correo,
        telefono: telefono,
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

      // Marcar cliente como deudor en la tabla clientes (si existe)
      try {
        await txn.update(
          'clientes',
          {'deudor': 1},
          where: 'id_cliente = ?',
          whereArgs: [deudor.idCliente],
        );
      } catch (_) {
        // Si no existe la tabla 'clientes' o falla, no detener la transacción.
      }

      return id;
    });
  }
  Future<List<Map<String, dynamic>>> getFacturasDeCliente(int idCliente) async {
    final db = await AppDatabase.instance.database;
    final res = await db.rawQuery('''
    SELECT 
      f.codigo_factura,
      f.fecha_emision,
      f.estado,
      d.plazo,
      v.total_base_cop,
      v.total_iva_cop,
      v.total_factura_cop
    FROM facturas f
    INNER JOIN deudores d ON f.id_factura = d.id_factura
    INNER JOIN vista_facturas_totales_ext v ON f.id_factura = v.id_factura
    WHERE d.id_cliente = ?
  ''', [idCliente]);
    return res;
  }

}
