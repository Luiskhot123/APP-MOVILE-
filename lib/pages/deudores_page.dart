import 'package:flutter/material.dart';
import '../data/deudores_repository.dart';
import '../widgets/app_drawer.dart';
import 'facturas_deudor_modal.dart';

class DeudoresPage extends StatefulWidget {
  const DeudoresPage({super.key});

  @override
  State<DeudoresPage> createState() => _DeudoresPageState();
}

class _DeudoresPageState extends State<DeudoresPage> {
  late Future<List<DeudorCliente>> _futureDeudores;

  @override
  void initState() {
    super.initState();
    _cargarDeudores();
  }

  void _cargarDeudores() {
    _futureDeudores = DeudoresRepository().obtenerDeudores();
  }

  Future<void> _refrescarLista() async {
    setState(() {
      _cargarDeudores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes Deudores'),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<DeudorCliente>>(
        future: _futureDeudores,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hay clientes deudores.'),
            );
          }

          final deudores = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refrescarLista,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: deudores.length,
              itemBuilder: (context, index) {
                final c = deudores[index];

                // ✅ Borde rojo solo si el plazo ya venció
                final BorderSide borde = c.diasRestantes < 0
                    ? const BorderSide(color: Colors.red, width: 2)
                    : BorderSide(color: Colors.grey.shade300, width: 1);

                // ✅ Calcular saldo restante
                final double saldoRestante =
                (c.totalDeuda - c.abono).clamp(0, double.infinity);

                return InkWell(
                  onTap: () async {
                    final facturas = await DeudoresRepository()
                        .getFacturasDeCliente(c.idCliente);

                    if (facturas.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Este cliente no tiene facturas pendientes')),
                      );
                      return;
                    }

                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.75,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        builder: (context, scrollController) {
                          return FacturasDeudorModal(
                            facturas: facturas,
                            nombreCliente: c.nombre,
                            scrollController: scrollController,
                          );
                        },
                      ),
                    );

                    // ✅ Refrescar automáticamente tras abono
                    if (result == true && mounted) {
                      await Future.delayed(const Duration(milliseconds: 300));
                      _refrescarLista();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: borde,
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Correo: ${c.correo}",
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Teléfono: ${c.telefono}",
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Dirección: ${c.direccion}",
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "Saldo restante",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                "\$${saldoRestante.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: saldoRestante > 0
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
