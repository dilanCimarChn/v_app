import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../views/HomeConductor.dart';
import '../views/HistorialConductor.dart';
import '../views/PerfilConductor.dart';
import '../views/GananciasConductor.dart';
import '../views/NotificacionesConductor.dart';
import '../views/PlanesConductor.dart';

class NavConductor extends StatefulWidget {
  const NavConductor({super.key});
  
  @override
  State<NavConductor> createState() => _NavConductorState();
}

class _NavConductorState extends State<NavConductor> {
  int _selectedIndex = 0;
  String _userName = '';
  
  final List<Widget> _views = const [
    HomeConductor(),
    HistorialConductor(),
    PerfilConductor(),
    GananciasConductor(),
    NotificacionesConductor(),
    PlanesConductor(),
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
        // Buscar en la colección usuario-app donde el email coincida y rol sea conductor
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user.email)
            .where('rol', isEqualTo: 'conductor')
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
        backgroundColor: Colors.teal.shade400,
        title: const Text("Conductor"),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Header con estilo verde (tono diferente al cliente)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.teal.shade400,
                    Colors.teal.shade300,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userName.isNotEmpty ? _userName : 'Cargando...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conductor Activo',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Lista de opciones del menú
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
                    icon: Icons.access_time,
                    text: 'Historial',
                    onTap: () => _onItemTapped(1),
                  ),
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    text: 'Perfil',
                    onTap: () => _onItemTapped(2),
                  ),
                  _buildMenuItem(
                    icon: Icons.attach_money_outlined,
                    text: 'Ganancias',
                    onTap: () => _onItemTapped(3),
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    text: 'Notificaciones',
                    onTap: () => _onItemTapped(4),
                  ),
                  _buildMenuItem(
                    icon: Icons.card_membership_outlined,
                    text: 'Planes / Membresía',
                    onTap: () => _onItemTapped(5),
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