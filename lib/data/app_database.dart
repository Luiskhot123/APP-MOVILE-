import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();
  Database? _db;

  static const String _dbFileName = 'DB_INVENTARIO_2.0.db'; // en assets/db/

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbFileName);

    if (!await File(dbPath).exists()) {
      await Directory(dirname(dbPath)).create(recursive: true);
      final data = await rootBundle.load('assets/db/$_dbFileName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath);
  }
}
