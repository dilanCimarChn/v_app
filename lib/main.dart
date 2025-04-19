import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:v_app/login/bienvenido.dart';
import 'package:v_app/login/inicia_sesion.dart';
import 'package:v_app/login/registrarse.dart';

import 'package:v_app/pages/cliente/HomeCliente.dart';
import 'package:v_app/pages/conductor/HomeConductor.dart';
import 'package:v_app/pages/conductor/views/forms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viaje Seguro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2E3B4E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E3B4E),
          primary: const Color(0xFF2E3B4E),
        ),
      ),
      initialRoute: '/ruta_inicial',
      routes: {
        '/': (context) => Bienvenido(),
        '/inicia_sesion': (context) => IniciaSesion(),
        '/registrarse': (context) => Registrarse(),
        '/home_cliente': (context) => HomeCliente(),
        '/home_conductor': (context) => HomeConductor(),
        '/verificacion_conductor': (context) => const VerificacionConductor(),
        '/ruta_inicial': (context) => const RutaInicial(),
      },
    );
  }
}

// Widget para determinar la ruta inicial basada en la sesión
class RutaInicial extends StatefulWidget {
  const RutaInicial({Key? key}) : super(key: key);

  @override
  _RutaInicialState createState() => _RutaInicialState();
}

class _RutaInicialState extends State<RutaInicial> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('loggedInUserEmail');
      final rol = prefs.getString('rol');

      if (email == null || email.isEmpty || rol == null || rol.isEmpty) {
        // No hay sesión activa, ir a bienvenido
        Navigator.pushReplacementNamed(context, '/');
      } else if (rol == 'cliente') {
        // Usuario es cliente, ir a HomeCliente
        Navigator.pushReplacementNamed(context, '/home_cliente');
      } else if (rol == 'conductor') {
        // Usuario es conductor, verificar solicitud
        Navigator.pushReplacementNamed(context, '/verificacion_conductor');
      }
    } catch (e) {
      // En caso de error, ir a la pantalla de bienvenida
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}