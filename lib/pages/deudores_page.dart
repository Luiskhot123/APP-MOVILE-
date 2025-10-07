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
    _futureDeudores = DeudoresRepository().obtenerDeudores();
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

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: deudores.length,
            itemBuilder: (context, index) {
              final c = deudores[index];

              // ✅ Borde rojo si el plazo venció
              final BorderSide borde = c.diasRestantes <= 0
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: Colors.grey.shade300, width: 1);

              return InkWell(
                onTap: () async {
                  // ✅ Obtener facturas del cliente antes de abrir el modal
                  final facturas = await DeudoresRepository()
                      .getFacturasDeCliente(c.idCliente);

                  if (facturas.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                        Text('Este cliente no tiene facturas pendientes'),
                      ),
                    );
                    return;
                  }

                  // ✅ Mostrar modal deslizable con facturas
                  showModalBottomSheet(
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
                },
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: borde,
                  ),
                  elevation: 3,
                  margin:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blueAccent,
                          child:
                          Icon(Icons.person, color: Colors.white, size: 28),
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
                              const SizedBox(height: 6),
                              Text(
                                "Abono: \$${c.abono.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: Colors.green,
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
                              "Deuda total",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "\$${c.totalDeuda.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.red,
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
          );
        },
      ),
    );
  }
}
