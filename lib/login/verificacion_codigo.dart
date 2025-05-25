import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../services/email_service.dart';

class VerificacionCodigo extends StatefulWidget {
  final String email;
  final String rol;
  final String nombre;
  final bool esNuevoUsuario;

  const VerificacionCodigo({
    super.key,
    required this.email,
    required this.rol,
    required this.nombre,
    this.esNuevoUsuario = false,
  });

  @override
  State<VerificacionCodigo> createState() => _VerificacionCodigoState();
}

class _VerificacionCodigoState extends State<VerificacionCodigo> {
  final TextEditingController _codigoController = TextEditingController();
  String? _codigoGenerado;
  bool _cargando = false;
  bool _enviandoCodigo = false;
  int _tiempoRestante = 300; // 5 minutos
  bool _puedeReenviar = false;

  @override
  void initState() {
    super.initState();
    _generarYEnviarCodigo();
    _iniciarTemporizador();
  }

  void _iniciarTemporizador() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _tiempoRestante--;
          if (_tiempoRestante <= 0) {
            _puedeReenviar = true;
          }
        });
        return _tiempoRestante > 0;
      }
      return false;
    });
  }

  String _formatearTiempo(int segundos) {
    int minutos = segundos ~/ 60;
    int segs = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}';
  }

  // FUNCIÓN MEJORADA PARA CANCELAR
  Future<void> _cancelarVerificacion() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar verificación?"),
        content: const Text("¿Estás seguro de que quieres cancelar? Podrás iniciar sesión con otra cuenta."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sí, cancelar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      // Limpiar cualquier sesión parcial
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserEmail');
      await prefs.remove('rol');
      await prefs.remove('loggedInUserName');
      
      // NUEVA: Marcar que venimos de cancelar verificación
      await prefs.setBool('saltar_verificacion', true);
      
      // Volver a la pantalla de login
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/registrarse', 
        (route) => false,
      );
    }
  }

  Future<void> _generarYEnviarCodigo() async {
    setState(() => _enviandoCodigo = true);
    
    final random = Random();
    _codigoGenerado = (100000 + random.nextInt(900000)).toString();

    try {
      await FirebaseFirestore.instance
          .collection('codigos_verificacion')
          .doc(widget.email)
          .set({
        'codigo': _codigoGenerado,
        'timestamp': FieldValue.serverTimestamp(),
        'usado': false,
        'intentos': 0,
      });

      bool emailEnviado = await EmailService.enviarCodigoVerificacion(
        email: widget.email,
        codigo: _codigoGenerado!,
        nombre: widget.nombre,
        esNuevoUsuario: widget.esNuevoUsuario,
      );

      if (emailEnviado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.esNuevoUsuario 
                      ? '✅ Código enviado a tu correo para confirmar registro'
                      : '✅ Código de verificación enviado por seguridad'
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        print('⚠️ FALLO ENVÍO EMAIL - Código para testing: $_codigoGenerado');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error enviando email. Revisa configuración.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      print('Error generando código: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _enviandoCodigo = false);
    }
  }

  Future<void> _verificarCodigo() async {
    final codigoIngresado = _codigoController.text.trim();
    
    if (codigoIngresado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el código de verificación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (codigoIngresado.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código debe tener 6 dígitos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('codigos_verificacion')
          .doc(widget.email)
          .get();

      if (!doc.exists) {
        throw Exception('Código no encontrado o expirado');
      }

      final data = doc.data()!;
      final codigoGuardado = data['codigo'];
      final usado = data['usado'] ?? false;
      final intentos = data['intentos'] ?? 0;
      final timestamp = data['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final tiempoTranscurrido = DateTime.now().difference(timestamp.toDate()).inMinutes;
        if (tiempoTranscurrido > 5) {
          throw Exception('El código ha expirado. Solicita uno nuevo.');
        }
      }

      if (usado) {
        throw Exception('Este código ya ha sido utilizado');
      }

      if (intentos >= 5) {
        throw Exception('Demasiados intentos fallidos. Solicita un nuevo código');
      }

      if (codigoIngresado == codigoGuardado) {
        await FirebaseFirestore.instance
            .collection('codigos_verificacion')
            .doc(widget.email)
            .update({'usado': true});

        if (widget.esNuevoUsuario) {
          final userQuery = await FirebaseFirestore.instance
              .collection('usuario-app')
              .where('email', isEqualTo: widget.email)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            await userQuery.docs.first.reference.update({'verificado': true});
          }
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', widget.email);
        await prefs.setString('rol', widget.rol);
        await prefs.setString('loggedInUserName', widget.nombre);

        // AGREGAR: Marcar dispositivo como conocido después de verificación exitosa
        await _actualizarInformacionDispositivo();

        await _registrarLoginExitoso();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text(widget.esNuevoUsuario 
                  ? '🎉 ¡Registro completado con éxito!'
                  : '✅ Verificación exitosa'
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        if (widget.rol == 'cliente') {
          Navigator.pushReplacementNamed(context, '/home_cliente');
        } else {
          Navigator.pushReplacementNamed(context, '/verificacion_conductor');
        }
      } else {
        await FirebaseFirestore.instance
            .collection('codigos_verificacion')
            .doc(widget.email)
            .update({'intentos': intentos + 1});

        num intentosRestantes = 4 - intentos;
        throw Exception(
          intentosRestantes > 0 
            ? 'Código incorrecto. Te quedan $intentosRestantes intentos'
            : 'Código incorrecto. Máximo de intentos alcanzado'
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  // NUEVA FUNCIÓN para actualizar información del dispositivo
  Future<void> _actualizarInformacionDispositivo() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultimo_login_${widget.email}', DateTime.now().toIso8601String());
      await prefs.setString('ultimo_dispositivo_${widget.email}', 'Móvil Flutter');
      print('✅ Dispositivo marcado como conocido para ${widget.email}');
    } catch (e) {
      print('Error actualizando información del dispositivo: $e');
    }
  }

  Future<void> _registrarLoginExitoso() async {
    try {
      await FirebaseFirestore.instance.collection('logs').add({
        'email': widget.email,
        'nombre': widget.nombre,
        'rol': widget.rol,
        'accion': widget.esNuevoUsuario ? 'registro_completado' : 'login_verificado',
        'timestamp': FieldValue.serverTimestamp(),
        'ip': 'N/A',
        'dispositivo': 'Móvil Flutter',
        'verificacion_2fa': true,
      });
    } catch (e) {
      print('Error registrando login: $e');
    }
  }

  Future<void> _reenviarCodigo() async {
    if (!_puedeReenviar || _enviandoCodigo) return;

    setState(() {
      _tiempoRestante = 300;
      _puedeReenviar = false;
      _codigoController.clear();
    });

    await _generarYEnviarCodigo();
    _iniciarTemporizador();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _cancelarVerificacion();
        return false; // Prevenir el pop automático
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF3E3),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3B4E)),
            onPressed: _cancelarVerificacion, // BOTÓN CANCELAR
          ),
          title: const Text(
            "Verificación de Seguridad",
            style: TextStyle(color: Color(0xFF2E3B4E)),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _cancelarVerificacion,
              child: const Text(
                "Cancelar",
                style: TextStyle(
                  color: Color(0xFF2E3B4E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 22, 196, 143).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  widget.esNuevoUsuario ? Icons.celebration : Icons.security,
                  size: 80,
                  color: const Color.fromARGB(255, 22, 196, 143),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                widget.esNuevoUsuario ? "¡Bienvenido!" : "Verificación de Identidad",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3B4E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                widget.esNuevoUsuario 
                  ? "Para completar tu registro, verifica tu identidad con el código enviado a:"
                  : "Por tu seguridad, verifica tu identidad con el código enviado a:",
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2E3B4E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 22, 196, 143).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 22, 196, 143),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              // NUEVA SECCIÓN - CAMBIAR CUENTA
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      "¿No eres tú? ",
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: _cancelarVerificacion,
                      child: const Text(
                        "Cambiar cuenta",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _codigoController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: "• • • • • •",
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    letterSpacing: 16,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 22, 196, 143)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 22, 196, 143), width: 2),
                  ),
                  counterText: "",
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color.fromARGB(255, 22, 196, 143)),
                ),
              ),
              const SizedBox(height: 20),
              if (_tiempoRestante > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.orange, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        "Expira en: ${_formatearTiempo(_tiempoRestante)}",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _verificarCodigo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3B4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 3,
                  ),
                  child: _cargando
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text("Verificando...", style: TextStyle(color: Colors.white)),
                          ],
                        )
                      : const Text(
                          "Verificar Código",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: (_puedeReenviar && !_enviandoCodigo) ? _reenviarCodigo : null,
                icon: _enviandoCodigo 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.refresh,
                        color: (_puedeReenviar && !_enviandoCodigo)
                            ? const Color.fromARGB(255, 22, 196, 143)
                            : Colors.grey,
                      ),
                label: Text(
                  _enviandoCodigo
                      ? "Enviando..."
                      : _puedeReenviar 
                          ? "Reenviar código"
                          : "Reenviar en ${_formatearTiempo(_tiempoRestante)}",
                  style: TextStyle(
                    color: (_puedeReenviar && !_enviandoCodigo)
                        ? const Color.fromARGB(255, 22, 196, 143)
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Si no recibes el email, revisa tu carpeta de spam o correo no deseado",
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }
}