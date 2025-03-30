import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await GoogleSignIn().signOut(); // Cerrar sesión de Google
      await FirebaseAuth.instance.signOut(); // Cerrar sesión de Firebase

      Navigator.of(context).pushReplacementNamed('/'); // Ir a Bienvenido
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio Cliente'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Esta es la vista del CLIENTE',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
