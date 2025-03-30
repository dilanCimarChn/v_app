import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:v_app/login/bienvenido.dart';
import 'package:v_app/login/inicia_sesion.dart';
import 'package:v_app/login/registrarse.dart';

import 'package:v_app/pages/cliente/HomeCliente.dart';
import 'package:v_app/pages/conductor/HomeConductor.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => Bienvenido(),
        '/inicia_sesion': (context) => IniciaSesion(),
        '/registrarse': (context) => Registrarse(),
        '/home_cliente': (context) => HomeCliente(),
        '/home_conductor': (context) => HomeConductor(),
      },
    );
  }
}
