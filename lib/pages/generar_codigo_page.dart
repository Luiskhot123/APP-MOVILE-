// lib/pages/generar_codigo_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/vinculacion_repository.dart';

class GenerarCodigoPage extends StatefulWidget {
  final int idEmpresa;
  const GenerarCodigoPage({super.key, required this.idEmpresa});

  @override
  State<GenerarCodigoPage> createState() => _GenerarCodigoPageState();
}

class _GenerarCodigoPageState extends State<GenerarCodigoPage> {
  final VinculacionRepository _repo = VinculacionRepository();

  bool _isAdmin = false;
  bool _isInventario = false;
  bool _isFacturacion = false;

  List<Map<String, dynamic>> _codigos = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCodigos();
  }

  Future<void> _loadCodigos() async {
    setState(() => _loading = true);
    try {
      final lista = await _repo.obtenerCodigosActivos(widget.idEmpresa);
      setState(() => _codigos = lista);
    } catch (e) {
      debugPrint('Error cargando códigos: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando códigos: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generarCodigo() async {
    int rolFinal = 0;
    if (_isAdmin) {
      rolFinal = 1;
    } else if (_isInventario && _isFacturacion) {
      rolFinal = 4;
    } else if (_isInventario) {
      rolFinal = 3;
    } else if (_isFacturacion) {
      rolFinal = 2;
    }

    if (rolFinal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un rol.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final nuevo = await _repo.generarCodigo(widget.idEmpresa, rolFinal);
      await _loadCodigos();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código generado: $nuevo')));
      await _repo.insertarCodigo(
        codigo: nuevo,
        idEmpresa: widget.idEmpresa,
        rol: rolFinal,
      );
    } catch (e) {
      debugPrint('Error generando código: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando código: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _copiarCodigo(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado al portapapeles')));
  }

  String _mapRol(int rol) {
    switch (rol) {
      case 1:
        return 'ADMIN';
      case 2:
        return 'FACTURACION';
      case 3:
        return 'INVENTARIO';
      case 4:
        return 'INVENTARIO-FACTURACION';
      default:
        return 'DESCONOCIDO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar código de vinculación'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('ADMIN'),
              value: _isAdmin,
              onChanged: (v) => setState(() {
                _isAdmin = v ?? false;
                if (_isAdmin) {
                  _isInventario = false;
                  _isFacturacion = false;
                }
              }),
            ),
            CheckboxListTile(
              title: const Text('INVENTARIO'),
              value: _isInventario,
              onChanged: _isAdmin
                  ? null
                  : (v) => setState(() => _isInventario = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('FACTURACION'),
              value: _isFacturacion,
              onChanged: _isAdmin
                  ? null
                  : (v) => setState(() => _isFacturacion = v ?? false),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generarCodigo,
                icon: const Icon(Icons.qr_code),
                label: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Generar / Guardar'),
              ),
            ),

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Códigos activos (${_codigos.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                onRefresh: _loadCodigos,
                child: _codigos.isEmpty
                    ? ListView( // para habilitar pull-to-refresh cuando está vacío
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [SizedBox(height: 200, child: Center(child: Text('No hay códigos activos')))],
                )
                    : ListView.separated(
                  itemCount: _codigos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = _codigos[index];
                    final code = row['code']?.toString() ?? '';
                    final rol = (row['rol'] is int) ? row['rol'] as int : int.tryParse(row['rol']?.toString() ?? '') ?? 0;
                    final created = row['created_at'] is int ? DateTime.fromMillisecondsSinceEpoch(row['created_at']) : null;
                    final expires = row['expires_at'] is int ? DateTime.fromMillisecondsSinceEpoch(row['expires_at']) : null;

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: code,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Rol: ${_mapRol(rol)}  •  Creado: ${created != null ? created.toLocal().toString().split('.').first : '-'}  •  Expira: ${expires != null ? expires.toLocal().toString().split('.').first : '-'}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () => _copiarCodigo(code),
                              child: const Text('Copiar'),
                            ),
                            const SizedBox(height: 6),
                            // opcional: botón para marcar manualmente como usado
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () async {
                                await _repo.marcarCodigoUsado(code);
                                await _loadCodigos();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código marcado como usado')));
                              },
                              child: const Text('Marcar usado'),
                            ),
                          ],
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
