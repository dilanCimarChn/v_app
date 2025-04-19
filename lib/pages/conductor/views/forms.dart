import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_app/pages/conductor/widgets/test_psicologico.dart';

// Pantalla principal que determina qué mostrar según el estado del conductor
class VerificacionConductor extends StatefulWidget {
  const VerificacionConductor({Key? key}) : super(key: key);

  @override
  _VerificacionConductorState createState() => _VerificacionConductorState();
}

class _VerificacionConductorState extends State<VerificacionConductor> {
  String _estado = 'cargando';
  bool _isLoading = true;
  String _userEmail = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Obtener datos de usuario de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('loggedInUserEmail') ?? '';
      final nombre = prefs.getString('loggedInUserName') ?? 'Usuario';

      setState(() {
        _userEmail = email;
        _userName = nombre;
      });

      if (email.isEmpty) {
        // Si no hay email almacenado, redirigir a inicio de sesión
        Navigator.pushReplacementNamed(context, '/inicia_sesion');
        return;
      }

      // Verificar si existe una solicitud en Firestore
      final solicitudDoc = await FirebaseFirestore.instance
          .collection('solicitudes_conductores')
          .doc(email)
          .get();

      if (solicitudDoc.exists) {
        // Si existe solicitud, obtener su estado
        setState(() {
          _estado = solicitudDoc['estado'] ?? 'pendiente';
          _isLoading = false;
        });
      } else {
        // Si no existe solicitud, mostrar formulario
        setState(() {
          _estado = 'nuevo';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _estado = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Mostrar pantalla según el estado
    switch (_estado) {
      case 'nuevo':
        return FormularioConductor(
          email: _userEmail,
          nombre: _userName,
        );
      case 'pendiente':
        return _PantallaRevisionPendiente(
          onCerrarSesion: _cerrarSesion,
        );
      case 'rechazado':
        return _PantallaRevisionRechazada(
          email: _userEmail, 
          onVolverAIntentar: _volverAFormulario,
          onCerrarSesion: _cerrarSesion,
        );
      case 'aprobado':
        // Si está aprobado, redireccionar a Home del conductor
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/home_conductor');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case 'error':
      default:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Ha ocurrido un error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _cargarDatos,
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: _cerrarSesion,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _volverAFormulario() async {
    try {
      // Eliminar solicitud actual
      await FirebaseFirestore.instance
          .collection('solicitudes_conductores')
          .doc(_userEmail)
          .delete();
      
      // Actualizar estado para mostrar formulario
      setState(() {
        _estado = 'nuevo';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserEmail');
      await prefs.remove('rol');
      await prefs.remove('loggedInUserName');
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }
}

// Pantalla de formulario para nuevos conductores
class FormularioConductor extends StatefulWidget {
  final String email;
  final String nombre;

  const FormularioConductor({
    Key? key,
    required this.email,
    required this.nombre,
  }) : super(key: key);

  @override
  _FormularioConductorState createState() => _FormularioConductorState();
}

class _FormularioConductorState extends State<FormularioConductor> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para campos del formulario
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _placaVehiculoController = TextEditingController();
  final _modeloVehiculoController = TextEditingController();
  final _licenciaURLController = TextEditingController();
  final _fotoPerfilURLController = TextEditingController();
  final _comentariosController = TextEditingController();
  
  // Variables para almacenar información
  String _licenciaCategoria = 'A';
  bool _isSubmitting = false;
  bool _testAprobado = false;

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor completa todos los campos requeridos")),
      );
      return;
    }

    if (!_testAprobado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes completar el test psicotécnico")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Crear documento en Firestore
      await FirebaseFirestore.instance.collection('solicitudes_conductores').doc(widget.email).set({
        'email': widget.email,
        'nombre': widget.nombre,
        'telefono': _telefonoController.text,
        'direccion': _direccionController.text,
        'placa_vehiculo': _placaVehiculoController.text,
        'modelo_vehiculo': _modeloVehiculoController.text,
        'licencia_categoria': _licenciaCategoria,
        'licenciaURL': _licenciaURLController.text,
        'foto_perfil': _fotoPerfilURLController.text,
        'test_psicotecnico': 'aprobado',
        'comentarios_adicionales': _comentariosController.text,
        'fecha_solicitud': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
      });

      // Actualizar preferencias locales
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('solicitudConductorEstado', 'pendiente');

      // Actualizar la pantalla para mostrar estado pendiente
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const VerificacionConductor(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar solicitud: $e")),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _realizarTest() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TestPsicologico(),
      ),
    );

    if (resultado == true) {
      setState(() {
        _testAprobado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test psicotécnico completado satisfactoriamente")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de Conductor'),
        backgroundColor: const Color(0xFF2E3B4E),
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Enviando solicitud...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Personal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Información precargada
                    ListTile(
                      title: const Text('Nombre'),
                      subtitle: Text(widget.nombre),
                      leading: const Icon(Icons.person),
                    ),
                    ListTile(
                      title: const Text('Email'),
                      subtitle: Text(widget.email),
                      leading: const Icon(Icons.email),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // URL foto de perfil
                    TextFormField(
                      controller: _fotoPerfilURLController,
                      decoration: const InputDecoration(
                        labelText: 'URL de foto de perfil',
                        prefixIcon: Icon(Icons.photo),
                        border: OutlineInputBorder(),
                        hintText: 'Enlace a tu foto de perfil',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa una URL para tu foto de perfil';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Teléfono
                    TextFormField(
                      controller: _telefonoController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu número de teléfono';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dirección
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu dirección completa';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Información del Vehículo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Placa del vehículo
                    TextFormField(
                      controller: _placaVehiculoController,
                      decoration: const InputDecoration(
                        labelText: 'Placa del Vehículo',
                        prefixIcon: Icon(Icons.directions_car),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa la placa de tu vehículo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Modelo del vehículo
                    TextFormField(
                      controller: _modeloVehiculoController,
                      decoration: const InputDecoration(
                        labelText: 'Modelo del Vehículo',
                        prefixIcon: Icon(Icons.car_rental),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa el modelo de tu vehículo';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Categoría de licencia
                    DropdownButtonFormField<String>(
                      value: _licenciaCategoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría de Licencia',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Categoría A')),
                        DropdownMenuItem(value: 'B', child: Text('Categoría B')),
                        DropdownMenuItem(value: 'C', child: Text('Categoría C')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _licenciaCategoria = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // URL de la licencia
                    TextFormField(
                      controller: _licenciaURLController,
                      decoration: const InputDecoration(
                        labelText: 'URL de la foto de tu licencia',
                        prefixIcon: Icon(Icons.insert_drive_file),
                        border: OutlineInputBorder(),
                        hintText: 'Enlace a la imagen de tu licencia',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa una URL para la foto de tu licencia';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Test psicotécnico
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Psicotécnico',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Debes completar el test psicotécnico para continuar con tu solicitud.',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _testAprobado
                                    ? const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text('Test completado'),
                                        ],
                                      )
                                    : const Text('Test pendiente'),
                                ElevatedButton(
                                  onPressed: _realizarTest,
                                  child: Text(_testAprobado ? 'Volver a realizar' : 'Realizar test'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Comentarios adicionales
                    TextFormField(
                      controller: _comentariosController,
                      decoration: const InputDecoration(
                        labelText: 'Comentarios adicionales (opcional)',
                        prefixIcon: Icon(Icons.comment),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Botón enviar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _enviarSolicitud,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E3B4E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Enviar Solicitud',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    _telefonoController.dispose();
    _direccionController.dispose();
    _placaVehiculoController.dispose();
    _modeloVehiculoController.dispose();
    _licenciaURLController.dispose();
    _fotoPerfilURLController.dispose();
    _comentariosController.dispose();
    super.dispose();
  }
}

// Pantalla de revisión pendiente
class _PantallaRevisionPendiente extends StatelessWidget {
  final VoidCallback onCerrarSesion;
  
  const _PantallaRevisionPendiente({
    Key? key,
    required this.onCerrarSesion,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Impedir el retroceso con el botón físico del dispositivo
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          color: const Color(0xFFFAF3E3),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in,
                    size: 150,
                    color: Color(0xFF2E3B4E),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Tu solicitud está en revisión',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3B4E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Estamos verificando tu información. Este proceso puede tomar hasta 48 horas hábiles.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E3B4E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Te notificaremos cuando hayamos completado la revisión.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E3B4E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Mientras revisamos tu solicitud, no podrás utilizar la aplicación como conductor.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  TextButton(
                    onPressed: onCerrarSesion,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla de solicitud rechazada
class _PantallaRevisionRechazada extends StatelessWidget {
  final String email;
  final VoidCallback onVolverAIntentar;
  final VoidCallback onCerrarSesion;
  
  const _PantallaRevisionRechazada({
    Key? key,
    required this.email,
    required this.onVolverAIntentar,
    required this.onCerrarSesion,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Impedir el retroceso con el botón físico del dispositivo
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          color: const Color(0xFFFAF3E3),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 100,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Solicitud rechazada',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Lo sentimos, tu solicitud para ser conductor ha sido rechazada.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Puedes volver a intentarlo proporcionando la información correcta.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: onVolverAIntentar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3B4E),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Volver a intentar',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: onCerrarSesion,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}