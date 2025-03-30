import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  NavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Principal',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'QR',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Mapa',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.attach_money),
          label: 'Estimador',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'Empresas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
      ],
      selectedItemColor: Color(0xFFFAF3E3), // Color claro para ítem seleccionado
      unselectedItemColor: Color(0xFFB0B0B0), // Color gris para ítems no seleccionados
      backgroundColor: Color(0xFF2E3B4E), // Color de fondo oscuro
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 14, // Tamaño de fuente del ítem seleccionado
      unselectedFontSize: 12, // Tamaño de fuente del ítem no seleccionado
    );
  }
}
