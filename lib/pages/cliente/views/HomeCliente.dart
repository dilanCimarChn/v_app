import 'package:flutter/material.dart';
import '../widgets/MapaClienteWidget.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Recomendaciones (chips)
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
