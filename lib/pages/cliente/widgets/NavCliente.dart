import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../views/HomeCliente.dart';
import '../views/HistorialCliente.dart';
import '../views/PerfilCliente.dart';
import '../views/PagosCliente.dart';
import '../views/ComentariosCliente.dart';
import '../views/NotificacionesCliente.dart';

class NavCliente extends StatefulWidget {
  const NavCliente({super.key});
  
  @override
  State<NavCliente> createState() => _NavClienteState();
}

class _NavClienteState extends State<NavCliente> {
  int _selectedIndex = 0;
  String _userName = '';
  
  final List<Widget> _views = const [
    HomeCliente(),
    HistorialCliente(),
    PerfilCliente(),
    PagosCliente(),
    ComentariosCliente(),
    NotificacionesCliente(),
  ];
  
  @override
  void initState() {
    super.initState();
    _getUserName();
  }
  
  Future<void> _getUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Buscar en la colección usuario-app donde el email coincida
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user.email)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            _userName = userData['name'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error obteniendo nombre de usuario: $e');
    }
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      Navigator.pop(context);
    });
  }
  
  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: true,
        title: const Text("Rol: Cliente"),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Header verde simplificado solo con nombre
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade400,
                    Colors.green.shade300,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nombre de usuario
                  Text(
                    _userName.isNotEmpty ? _userName : 'Cargando...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Lista de opciones del menú en español
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10),
                children: [
                  _buildMenuItem(
                    icon: Icons.home_outlined,
                    text: 'Inicio',
                    onTap: () => _onItemTapped(0),
                  ),
                  _buildMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    text: 'Mi Billetera',
                    onTap: () => _onItemTapped(3),
                  ),
                  _buildMenuItem(
                    icon: Icons.access_time,
                    text: 'Historial',
                    onTap: () => _onItemTapped(1),
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    text: 'Notificaciones',
                    onTap: () => _onItemTapped(5),
                  ),
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    text: 'Perfil',
                    onTap: () => _onItemTapped(2),
                  ),
                  _buildMenuItem(
                    icon: Icons.star_outline,
                    text: 'Comentarios',
                    onTap: () => _onItemTapped(4),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    text: 'Configuración',
                    onTap: () => _onItemTapped(2),
                  ),
                  const Divider(),
                  _buildMenuItem(
                    icon: Icons.logout,
                    text: 'Cerrar sesión',
                    onTap: _signOut,
                    textColor: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _views[_selectedIndex],
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(
        icon,
        color: Colors.grey.shade600,
        size: 24,
      ),
      title: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}