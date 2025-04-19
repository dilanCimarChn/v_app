import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Registrarse extends StatefulWidget {
  @override
  _RegistrarseState createState() => _RegistrarseState();
}

class _RegistrarseState extends State<Registrarse> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa correo y contraseña")),
      );
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('usuario-app')
          .where('email', isEqualTo: email)
          .get();

      if (query.docs.isNotEmpty) {
        final user = query.docs.first;
        if (user['password'] == password) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUserEmail', email);
          await prefs.setString('rol', user['rol']);
          await prefs.setString('loggedInUserName', user['name'] ?? 'Usuario');

          if (user['rol'] == 'cliente') {
            Navigator.pushReplacementNamed(context, '/home_cliente');
          } else {
            // Si es conductor, verificar su estado
            Navigator.pushReplacementNamed(context, '/verificacion_conductor');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Contraseña incorrecta")),
          );
        }
      } else {
        _showRegistroEmergente(email, password);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _showRegistroEmergente(String email, String password) async {
    final TextEditingController nameCtrl = TextEditingController();
    String? selectedRol;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Registro"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nombre completo"),
            ),
            DropdownButtonFormField<String>(
              value: selectedRol,
              hint: const Text("Selecciona tu rol"),
              items: const [
                DropdownMenuItem(value: 'cliente', child: Text("Cliente")),
                DropdownMenuItem(value: 'conductor', child: Text("Conductor")),
              ],
              onChanged: (value) => selectedRol = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Guardar"),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || selectedRol == null) return;

              await FirebaseFirestore.instance.collection('usuario-app').add({
                'name': nameCtrl.text.trim(),
                'email': email,
                'password': password,
                'rol': selectedRol,
              });

              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('loggedInUserEmail', email);
              await prefs.setString('rol', selectedRol!);
              await prefs.setString('loggedInUserName', nameCtrl.text.trim());

              Navigator.of(context).pop();
              
              if (selectedRol == 'cliente') {
                Navigator.pushReplacementNamed(context, '/home_cliente');
              } else {
                Navigator.pushReplacementNamed(context, '/verificacion_conductor');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _registrarseConGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return;

      final docs = await FirebaseFirestore.instance
          .collection('usuario-app')
          .where('email', isEqualTo: user.email)
          .get();

      if (docs.docs.isNotEmpty) {
        final rol = docs.docs.first['rol'];
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', user.email ?? '');
        await prefs.setString('rol', rol);
        await prefs.setString('loggedInUserName', user.displayName ?? 'Usuario');

        if (rol == 'cliente') {
          Navigator.pushReplacementNamed(context, '/home_cliente');
        } else {
          Navigator.pushReplacementNamed(context, '/verificacion_conductor');
        }
      } else {
        await _showGoogleRegistroEmergente(user.email!, user.displayName ?? '');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error con Google: $e")),
      );
    }
  }

  Future<void> _showGoogleRegistroEmergente(String email, String nombre) async {
    final TextEditingController pass1 = TextEditingController();
    final TextEditingController pass2 = TextEditingController();
    String? rol;
    bool _obscure1 = true;
    bool _obscure2 = true;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => WillPopScope(
        onWillPop: () async {
          await GoogleSignIn().signOut();
          return true;
        },
        child: StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            title: const Text("Crear contraseña y seleccionar rol"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: rol,
                  hint: const Text("Selecciona tu rol"),
                  items: const [
                    DropdownMenuItem(value: 'cliente', child: Text("Cliente")),
                    DropdownMenuItem(value: 'conductor', child: Text("Conductor")),
                  ],
                  onChanged: (value) => setModalState(() => rol = value),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: pass1,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: "Crea una Contraseña",
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setModalState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                ),
                TextField(
                  controller: pass2,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: "Repetir contraseña",
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setModalState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await GoogleSignIn().signOut();
                  Navigator.pop(context);
                },
                child: const Text("Cerrar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (pass1.text.trim() != pass2.text.trim() || rol == null) return;

                  await FirebaseFirestore.instance.collection('usuario-app').add({
                    'name': nombre,
                    'email': email,
                    'password': pass1.text.trim(),
                    'rol': rol,
                  });

                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setString('loggedInUserEmail', email);
                  await prefs.setString('rol', rol!);
                  await prefs.setString('loggedInUserName', nombre);

                  Navigator.of(context).pop();
                  
                  if (rol == 'cliente') {
                    Navigator.pushReplacementNamed(context, '/home_cliente');
                  } else {
                    Navigator.pushReplacementNamed(context, '/verificacion_conductor');
                  }
                },
                child: const Text("Guardar"),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E3),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("Iniciar Sesión", style: TextStyle(color: Color(0xFF2E3B4E))),
        iconTheme: const IconThemeData(color: Color(0xFF2E3B4E)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Image.network(
              'https://i.ibb.co/xtN8mjLv/logo.png',
              height: MediaQuery.of(context).size.height * 0.3,
              errorBuilder: (context, error, stackTrace) => 
                Icon(Icons.image, size: MediaQuery.of(context).size.height * 0.3, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: _buildInputDecoration("Correo electrónico"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _buildInputDecoration("Contraseña").copyWith(
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF2E3B4E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleEmailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E3B4E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 80),
              ),
              child: const Text("Continuar", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _registrarseConGoogle,
              icon: const Icon(Icons.account_circle),
              label: const Text("Iniciar con Google"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFFDFCFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
    );
  }
}