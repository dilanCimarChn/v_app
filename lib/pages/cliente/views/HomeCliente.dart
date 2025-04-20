import 'package:flutter/material.dart';
import '../widgets/MapaClienteWidget.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior de búsqueda
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: "¿A dónde vas?",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              fillColor: Colors.grey[100],
              filled: true,
            ),
            onTap: () {
              // Aquí se puede abrir una pantalla para elegir destino
            },
          ),
        ),

        // Recomendaciones (chips)
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: const [
              _UbicacionChip(nombre: "Casa"),
              _UbicacionChip(nombre: "Trabajo"),
              _UbicacionChip(nombre: "Plaza Central"),
              _UbicacionChip(nombre: "Aeropuerto"),
            ],
          ),
        ),

        // Mapa
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const MapaClienteWidget(),
          ),
        ),

        // Botón para solicitar viaje
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              // Aquí se enviaría la solicitud de viaje
            },
            icon: const Icon(Icons.directions_car),
            label: const Text("Solicitar viaje"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blueAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _UbicacionChip extends StatelessWidget {
  final String nombre;
  const _UbicacionChip({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Chip(
        label: Text(nombre),
        avatar: const Icon(Icons.place, size: 18),
        backgroundColor: Colors.grey[200],
      ),
    );
  }
}
