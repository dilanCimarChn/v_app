import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/MapaClienteWidget.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  // ⚠ Reemplaza por la URL actual generada por Ngrok
  final String ngrokUrl = 'https://2f68-2800-cd0-165-3459-d11f-a8e1-bbe5-b4b2.ngrok-free.app';

  void _abrirStream(BuildContext context) async {
    final Uri url = Uri.parse(ngrokUrl);

    try {
      // Lanza directamente el navegador sin verificar con canLaunchUrl
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw 'No se pudo abrir el navegador';
      }
    } catch (e) {
      // Muestra error visual en caso de fallo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el stream: $e')),
      );
    }
  }

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

        // Botón de Stream
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Text('Ver cámara en vivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => _abrirStream(context),
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