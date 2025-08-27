import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;

  AppDatabase._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB("DB_INVENTARIO_2.0.db");
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, fileName);

    // Si la BD no existe en el dispositivo, la copiamos desde assets
    if (!await File(dbPath).exists()) {
      print("📂 Copiando BD desde assets a $dbPath");
      final data = await rootBundle.load("assets/db/$fileName");
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    } else {
      print("✅ Usando BD existente en $dbPath");
    }

    return await openDatabase(dbPath);
  }
}

