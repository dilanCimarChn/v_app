import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/MapaClienteWidget.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  // ⚠ Reemplaza por la URL actual generada por Ngrok
  final String ngrokUrl = 'https://5fd1-131-0-196-140.ngrok-free.app/';

  void _abrirStreamModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // No se cierra tocando fuera
      builder: (BuildContext context) {
        return StreamModal(url: ngrokUrl);
      },
    );
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
            onPressed: () => _abrirStreamModal(context),
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

class StreamModal extends StatefulWidget {
  final String url;
  
  const StreamModal({super.key, required this.url});

  @override
  State<StreamModal> createState() => _StreamModalState();
}

class _StreamModalState extends State<StreamModal> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Configurar el WebViewController
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header con botón cerrar
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text(
                        'Cámara en Vivo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // WebView content
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: controller),
                  
                  // Indicador de carga
                  if (isLoading)
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.redAccent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Cargando stream...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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