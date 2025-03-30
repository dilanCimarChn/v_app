import 'package:flutter/material.dart';

class Bienvenido extends StatefulWidget {
  const Bienvenido({super.key});

  @override
  State<Bienvenido> createState() => _BienvenidoState();
}

class _BienvenidoState extends State<Bienvenido> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.2, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navegarAInicioSesion() {
    print("Intentando navegar a /inicia_sesion");
    Navigator.of(context).pushReplacementNamed('/inicia_sesion');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E3),
      body: Listener(
        onPointerUp: (event) {
          if (event.delta.dx < -10) {
            _navegarAInicioSesion();
          }
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
              _navegarAInicioSesion();
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Image.network(
                      'https://i.ibb.co/xtN8mjLv/logo.png',
                      height: 350,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 350,
                          width: 350,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 100, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Bienvenido a Viaje Seguro",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3B4E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Desliza para comenzar tu viaje",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E3B4E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SlideTransition(
                        position: _animation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swipe_left, color: const Color.fromARGB(255, 22, 196, 143), size: 30),
                            const SizedBox(width: 8),
                            Text(
                              "Desliza hacia la izquierda",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(255, 22, 196, 143),
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
        ),
      ),
      floatingActionButton: SizedBox(
        width: 20,
        height: 20,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _navegarAInicioSesion,
          child: const Icon(Icons.arrow_forward, size: 0),
        ),
      ),
    );
  }
}
