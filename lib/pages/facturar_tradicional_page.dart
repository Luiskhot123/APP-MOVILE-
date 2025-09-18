import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../models/product.dart';
import '../models/venta_item.dart';
import '../models/cliente.dart';
import '../data/cliente_repository.dart';
import 'crear_cliente_page.dart';

class FacturarTradicionalPage extends StatefulWidget {
  const FacturarTradicionalPage({super.key});

  @override
  State<FacturarTradicionalPage> createState() => _FacturarTradicionalPageState();
}

class _FacturarTradicionalPageState extends State<FacturarTradicionalPage> {
  final _repo = ProductRepository();
  final Map<int, VentaItem> _carrito = {}; // key = id_producto
  Cliente? _clienteSeleccionado;

  // NOTA: no creamos aquí el controller de campo de texto de Autocomplete;
  // usaremos el que Autocomplete nos pasa en fieldViewBuilder.
  TextEditingController? _fieldController;
  FocusNode? _fieldFocusNode;

  // Sugerencias devueltas por la DB (llenadas via debounce)
  List<Product> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preguntarFacturaElectronica());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // quitar listener del controller anterior (si existe) — no lo disposeamos
    _fieldController?.removeListener(_onSearchChanged);
    super.dispose();
  }

  // -------- Modal de factura electrónica y validación de cliente (igual que VenderPage) --------
  Future<void> _preguntarFacturaElectronica() async {
    final deseaFactura = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('¿Desea factura electrónica?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí')),
          ],
        );
      },
    );

    if (deseaFactura == true) {
      final cliente = await mostrarModalValidacionCliente(context);
      if (cliente != null) {
        setState(() => _clienteSeleccionado = cliente);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cliente: ${cliente.nombreCompleto}')),
        );
      } else {
        // si cancela, volvemos a preguntar
        await _preguntarFacturaElectronica();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta sin cliente asociado')));
    }
  }

  Future<Cliente?> mostrarModalValidacionCliente(BuildContext context) {
    final repo = ClienteRepository();
    final formKey = GlobalKey<FormState>();
    final numeroCtrl = TextEditingController();
    int tipoSeleccionado = 1; // default CC
    String? errorDoc;

    final tipos = {
      1: 'Cédula de ciudadanía',
      2: 'NIT',
      3: 'Cédula de extranjería',
    };

    return showDialog<Cliente>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Validar cliente'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: tipoSeleccionado,
                      items: tipos.entries
                          .map((e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => tipoSeleccionado = v ?? 1),
                      decoration: const InputDecoration(labelText: 'Tipo documento'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: numeroCtrl,
                      decoration: InputDecoration(labelText: 'Número de identificación', errorText: errorDoc),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingrese número' : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          final creado = await showDialog(context: context, builder: (_) => const CrearClientePage());
                          if (creado == true) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente creado, vuelva a validar')));
                          }
                        },
                        child: const Text("Crear cliente", style: TextStyle(decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final cliente = await repo.findByTipoYDocumento(tipoSeleccionado, numeroCtrl.text.trim());
                    if (cliente == null) {
                      setState(() => errorDoc = "Cliente inexistente");
                    } else {
                      Navigator.pop(ctx, cliente);
                    }
                  },
                  child: const Text("Continuar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ------------------ lógica carrito ------------------
  void _agregarProducto(Product p) {
    setState(() {
      if (_carrito.containsKey(p.id)) {
        _carrito[p.id]!.qty++;
      } else {
        _carrito[p.id] = VentaItem(product: p, qty: 1);
      }
    });
  }

  void _increment(int id) => setState(() => _carrito[id]!.qty++);
  void _decrement(int id) {
    setState(() {
      final item = _carrito[id]!;
      if (item.qty > 1) {
        item.qty--;
      } else {
        _carrito.remove(id);
      }
    });
  }

  int get _totalCOP {
    double t = 0;
    for (final v in _carrito.values) t += v.total;
    return t.toInt();
  }

  int get _subtotalCOP {
    double t = 0;
    for (final v in _carrito.values) t += v.subtotal;
    return t.toInt();
  }

  String _formatCOP(int n) {
    final s = n.abs().toString();
    final out = <String>[];
    var c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      out.add(s[i]);
      c++;
      if (c == 3 && i != 0) {
        out.add('.');
        c = 0;
      }
    }
    return '\$${out.reversed.join()} COP';
  }

  // ------------------ búsqueda con debounce ------------------
  void _onSearchChanged() {
    final q = _fieldController?.text ?? '';
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final query = q.trim();
      if (query.isEmpty) {
        if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
        return;
      }
      try {
        final results = await _repo.searchProducts(query);
        if (!mounted) return;
        setState(() => _suggestions = results);
      } catch (e) {
        // puedes loggear o manejar el error
        if (!mounted) return;
        setState(() => _suggestions = []);
      }
    });
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Facturar tradicional")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Autocomplete<Product>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final txt = textEditingValue.text;
                if (txt.isEmpty) return const Iterable<Product>.empty();
                final q = txt.toLowerCase();
                // devolvemos las sugerencias ya consultadas y filtradas por seguridad
                return _suggestions.where((p) => p.nombre.toLowerCase().contains(q));
              },
              displayStringForOption: (p) => p.nombre,
              onSelected: (p) {
                _agregarProducto(p);
                // limpiar campo y volver a dar foco
                _fieldController?.clear();
                _fieldFocusNode?.requestFocus();
                // limpiar sugerencias visibles
                setState(() => _suggestions = []);
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onEditingComplete) {
                // Si cambia el controller que nos entrega Autocomplete,
                // removemos listener del anterior y nos suscribimos al nuevo.
                if (_fieldController != textEditingController) {
                  _fieldController?.removeListener(_onSearchChanged);
                  _fieldController = textEditingController;
                  _fieldController!.addListener(_onSearchChanged);
                }
                _fieldFocusNode = focusNode;

                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Buscar producto",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onEditingComplete: onEditingComplete,
                );
              },
            ),
          ),

          Expanded(
            child: _carrito.isEmpty
                ? const Center(child: Text("Agrega productos"))
                : ListView(
              padding: const EdgeInsets.all(12),
              children: _carrito.entries.map((e) {
                final item = e.value;
                return _VentaItemTile(
                  item: item,
                  onInc: () => _increment(e.key),
                  onDec: () => _decrement(e.key),
                  onRemove: () => setState(() => _carrito.remove(e.key)),
                );
              }).toList(),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Row(children: [const Text("Subtotal: "), const Spacer(), Text(_formatCOP(_subtotalCOP))]),
                Row(children: [
                  const Text("Total: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(_formatCOP(_totalCOP), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Cancelar factura"),
                            content: const Text("¿Está seguro que desea cancelar la factura?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Regresar"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () {
                                  // 👇 Aquí limpias el carrito y reinicias todo
                                  setState(() {
                                    _carrito.clear();
                                  });
                                  Navigator.pop(context); // cerrar modal
                                },
                                child: const Text("Sí, Cancelar"),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text("Cancelar"),
                    ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Aquí integras la lógica para guardar factura (como en VenderPage)
                        },
                        child: const Text("Vender"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VentaItemTile extends StatelessWidget {
  final VentaItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _VentaItemTile({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = item.product;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.image),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.categoria != null) Text(p.categoria!, style: const TextStyle(color: Colors.grey)),
                    Text("Precio base: ${p.precio.toInt()}"),
                    Text("IVA: ${p.ivaPct.toStringAsFixed(0)}%"),
                    Row(
                      children: [
                        IconButton(onPressed: onDec, icon: const Icon(Icons.remove_circle_outline)),
                        Text("${item.qty}"),
                        IconButton(onPressed: onInc, icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("\$${item.total.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Subtotal: \$${item.subtotal.toInt()}"),
                ],
              )
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 16, color: Colors.white)),
          ),
        )
      ],
    );
  }
}
