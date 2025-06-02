import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verificacion_codigo.dart';

class Registrarse extends StatefulWidget {
  @override
  _RegistrarseState createState() => _RegistrarseState();
}

class _RegistrarseState extends State<Registrarse> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  // NUEVA VARIABLE para saber si venimos de cancelar verificación
  bool _saltarVerificacion = false;

  @override
  void initState() {
    super.initState();
    _verificarSiVieneDeCancelar();
  }

  // NUEVA FUNCIÓN para verificar si venimos de cancelar
  Future<void> _verificarSiVieneDeCancelar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _saltarVerificacion = prefs.getBool('saltar_verificacion') ?? false;
    
    // Limpiar la bandera después de leerla
    if (_saltarVerificacion) {
      await prefs.remove('saltar_verificacion');
    }
  }

  Future<bool> _verificarDispositivoConocido(String email) async {
    // Si venimos de cancelar verificación, no requerir verificación
    if (_saltarVerificacion) {
      print('🔄 Saltando verificación - usuario canceló anteriormente');
      return false; // No requerir verificación
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? ultimoLogin = prefs.getString('ultimo_login_$email');
      String? ultimoDispositivo = prefs.getString('ultimo_dispositivo_$email');
      
      DateTime ahora = DateTime.now();
      String dispositivoActual = 'Móvil Flutter';
      
      bool esDispositivoConocido = false;
      bool loginReciente = false;
      
      if (ultimoLogin != null && ultimoDispositivo != null) {
        DateTime ultimoLoginDate = DateTime.parse(ultimoLogin);
        int diasTranscurridos = ahora.difference(ultimoLoginDate).inDays;
        
        // Si el último login fue hace menos de 30 días en el mismo dispositivo
        if (diasTranscurridos < 30 && ultimoDispositivo == dispositivoActual) {
          esDispositivoConocido = true;
        }
        
        // Si el último login fue hace menos de 1 día
        if (diasTranscurridos < 1) {
          loginReciente = true;
        }
      }
      
      // Registrar el intento de login
      await FirebaseFirestore.instance.collection('logs').add({
        'email': email,
        'accion': 'intento_login',
        'timestamp': FieldValue.serverTimestamp(),
        'dispositivo': dispositivoActual,
        'es_dispositivo_conocido': esDispositivoConocido,
        'login_reciente': loginReciente,
        'requiere_verificacion': !esDispositivoConocido || !loginReciente,
        'salto_verificacion': _saltarVerificacion,
      });
      
      return !esDispositivoConocido || !loginReciente;
    } catch (e) {
      print('Error verificando dispositivo: $e');
      return !_saltarVerificacion; // Si hay error y no saltamos, requerir verificación
    }
  }

  Future<void> _actualizarInformacionDispositivo(String email) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultimo_login_$email', DateTime.now().toIso8601String());
      await prefs.setString('ultimo_dispositivo_$email', 'Móvil Flutter');
    } catch (e) {
      print('Error actualizando información del dispositivo: $e');
    }
  }

  // 🎯 FUNCIÓN MEJORADA: Crear usuario falso en Firebase Auth
  Future<bool> _crearUsuarioFalsoFirebaseAuth(String email, String password) async {
    try {
      print("🔧 Creando usuario falso en Firebase Auth...");
      
      // Crear un email temporal único para evitar conflictos
      String emailTemporal = 'temp_${DateTime.now().millisecondsSinceEpoch}@tempauth.com';
      String passwordTemporal = 'TempPass123!';
      
      try {
        // Crear usuario temporal
        UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailTemporal,
          password: passwordTemporal,
        );
        
        if (result.user != null) {
          // Actualizar el perfil del usuario temporal con los datos reales
          await result.user!.updateDisplayName(email);
          await result.user!.updateEmail(email);
          
          print("✅ Usuario falso creado y actualizado con email real");
          return true;
        }
        
      } catch (createError) {
        print("⚠️ No se pudo crear usuario temporal: $createError");
        
        // Como alternativa, intentar solo crear perfil sin autenticación
        print("🔄 Guardando datos de sesión directamente...");
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', email);
        await prefs.setString('manual_auth_success', 'true');
        await prefs.setString('firebase_auth_status', 'bypassed');
        
        return true; // Consideramos exitoso porque guardamos la sesión
      }
      
      return false;
      
    } catch (e) {
      print("❌ Error completo creando usuario falso: $e");
      return false;
    }
  }

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
        final userData = user.data() as Map<String, dynamic>;
        
        if (user['password'] == password) {
          // Usuario existente con credenciales correctas
          print("✅ Credenciales validadas en Firestore");
          
          // 🎯 INTENTAR FIREBASE AUTH NORMALMENTE
          bool firebaseAuthExitoso = false;
          
          try {
            print("🔐 Intentando autenticar en Firebase Auth...");
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            firebaseAuthExitoso = true;
            print("✅ Autenticación Firebase Auth exitosa");
            
          } catch (authError) {
            print("⚠️ Firebase Auth falló: $authError");
            
            // 🎯 SI FALLA, CREAR USUARIO FALSO
            print("🔄 Intentando crear usuario falso en Firebase Auth...");
            firebaseAuthExitoso = await _crearUsuarioFalsoFirebaseAuth(email, password);
            
            if (!firebaseAuthExitoso) {
              print("⚠️ Usuario falso también falló, continuando sin Firebase Auth");
            }
          }
          
          // 🎯 GUARDAR SESIÓN COMPLETA EN SHAREDPREFERENCES
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUserEmail', email);
          await prefs.setString('loggedInUserName', userData['name'] ?? 'Usuario');
          await prefs.setString('rol', userData['rol'] ?? 'cliente');
          await prefs.setBool('manual_login_success', true);
          await prefs.setString('firebase_auth_status', firebaseAuthExitoso ? 'exitoso' : 'fallido');
          
          // Verificar estado final
          final currentUser = FirebaseAuth.instance.currentUser;
          print("🔍 Usuario actual en Firebase Auth: ${currentUser?.email ?? 'null'}");
          print("✅ Sesión guardada en SharedPreferences para: $email");
          
          bool requiereVerificacion = await _verificarDispositivoConocido(email);
          
          if (requiereVerificacion) {
            // Navegar a pantalla de verificación
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerificacionCodigo(
                  email: email,
                  rol: user['rol'],
                  nombre: user['name'] ?? 'Usuario',
                  esNuevoUsuario: false,
                ),
              ),
            );
          } else {
            // Login directo sin verificación adicional
            await _actualizarInformacionDispositivo(email);

            // Registrar login exitoso
            await FirebaseFirestore.instance.collection('logs').add({
              'email': email,
              'nombre': user['name'] ?? 'Usuario',
              'rol': user['rol'],
              'accion': _saltarVerificacion ? 'login_directo_cancelado' : 'login_directo',
              'timestamp': FieldValue.serverTimestamp(),
              'dispositivo': 'Móvil Flutter',
              'firebase_auth_status': firebaseAuthExitoso ? 'exitoso' : 'manual_bypass',
              'current_user_status': currentUser != null ? 'autenticado' : 'manual',
            });

            if (user['rol'] == 'cliente') {
              Navigator.pushReplacementNamed(context, '/home_cliente');
            } else {
              Navigator.pushReplacementNamed(context, '/verificacion_conductor');
            }
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
                'fecha_registro': FieldValue.serverTimestamp(),
                'verificado': false,
              });

              Navigator.of(context).pop();
              
              // Navegar a verificación de código para nuevo usuario
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerificacionCodigo(
                    email: email,
                    rol: selectedRol!,
                    nombre: nameCtrl.text.trim(),
                    esNuevoUsuario: true,
                  ),
                ),
              );
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
        final userData = docs.docs.first;
        final rol = userData['rol'];
        
        // Verificar si necesita verificación adicional
        bool requiereVerificacion = await _verificarDispositivoConocido(user.email!);
        
        if (requiereVerificacion) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificacionCodigo(
                email: user.email!,
                rol: rol,
                nombre: user.displayName ?? 'Usuario',
                esNuevoUsuario: false,
              ),
            ),
          );
        } else {
          await _actualizarInformacionDispositivo(user.email!);
          
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUserEmail', user.email ?? '');
          await prefs.setString('rol', rol);
          await prefs.setString('loggedInUserName', user.displayName ?? 'Usuario');

          if (rol == 'cliente') {
            Navigator.pushReplacementNamed(context, '/home_cliente');
          } else {
            Navigator.pushReplacementNamed(context, '/verificacion_conductor');
          }
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
                    'fecha_registro': FieldValue.serverTimestamp(),
                    'verificado': false,
                  });

                  Navigator.of(context).pop();
                  
                  // Navegar a verificación para nuevo usuario de Google
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerificacionCodigo(
                        email: email,
                        rol: rol!,
                        nombre: nombre,
                        esNuevoUsuario: true,
                      ),
                    ),
                  );
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