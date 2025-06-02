import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PerfilConductor extends StatefulWidget {
  const PerfilConductor({super.key});

  @override
  State<PerfilConductor> createState() => _PerfilConductorState();
}

class _PerfilConductorState extends State<PerfilConductor> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  // Controladores para los campos básicos
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _emergenciaContactoController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();
  
  // Controladores específicos para conductor
  final _placaVehiculoController = TextEditingController();
  final _modeloVehiculoController = TextEditingController();
  final _licenciaCategoriaController = TextEditingController();
  final _comentariosAdicionalesController = TextEditingController();
  
  // Controladores para cambio de contraseña
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final _passwordConfirmarController = TextEditingController();
  
  // Estados
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  Map<String, dynamic> _datosUsuario = {};
  String? _documentId;
  
  // Estados específicos para conductor
  String _estadoSolicitud = 'pendiente';
  bool _testPsicotecnicoAprobado = false;
  
  // Colores
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color conductorColor = Color(0xFF9C27B0);

  @override
  void initState() {
    super.initState();
    _cargarDatosConductor();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _fechaNacimientoController.dispose();
    _cedulaController.dispose();
    _emergenciaContactoController.dispose();
    _emergenciaTelefonoController.dispose();
    _placaVehiculoController.dispose();
    _modeloVehiculoController.dispose();
    _licenciaCategoriaController.dispose();
    _comentariosAdicionalesController.dispose();
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosConductor() async {
    print("🔍 Iniciando carga de datos del conductor...");
    
    if (user == null) {
      print("❌ User es null");
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    print("✅ User ID: ${user!.uid}");
    print("✅ User Email: ${user!.email}");
    
    try {
      // Primero buscar en solicitudes_conductores
      print("🔍 Buscando en solicitudes_conductores...");
      
      final solicitudQuery = await FirebaseFirestore.instance
          .collection('solicitudes_conductores')
          .where('email', isEqualTo: user!.email)
          .get();
      
      if (solicitudQuery.docs.isNotEmpty) {
        final datos = solicitudQuery.docs.first.data();
        print("📊 Datos de solicitud encontrados: $datos");
        
        setState(() {
          _datosUsuario = datos;
          _documentId = solicitudQuery.docs.first.id;
          _nombreController.text = datos['nombre'] ?? '';
          _emailController.text = datos['email'] ?? '';
          _telefonoController.text = datos['telefono'] ?? '';
          _direccionController.text = datos['direccion'] ?? '';
          _placaVehiculoController.text = datos['placa_vehiculo'] ?? '';
          _modeloVehiculoController.text = datos['modelo_vehiculo'] ?? '';
          _licenciaCategoriaController.text = datos['licencia_categoria'] ?? '';
          _comentariosAdicionalesController.text = datos['comentarios_adicionales'] ?? '';
          _estadoSolicitud = datos['estado'] ?? 'pendiente';
          _testPsicotecnicoAprobado = datos['test_psicotecnico'] == 'aprobado';
          _isLoading = false;
        });
        print("✅ Estado actualizado correctamente desde solicitudes");
        return;
      }
      
      // Si no está en solicitudes, buscar en usuario-app
      print("🔍 Buscando en usuario-app...");
      
      final doc = await FirebaseFirestore.instance
          .collection('usuario-app')
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        final datos = doc.data() as Map<String, dynamic>;
        print("📊 Datos de usuario encontrados: $datos");
        
        setState(() {
          _datosUsuario = datos;
          _documentId = user!.uid;
          _nombreController.text = datos['name'] ?? '';
          _emailController.text = datos['email'] ?? '';
          _telefonoController.text = datos['telefono'] ?? '';
          _direccionController.text = datos['direccion'] ?? '';
          _fechaNacimientoController.text = datos['fecha_nacimiento'] ?? '';
          _cedulaController.text = datos['cedula'] ?? '';
          _emergenciaContactoController.text = datos['emergencia_contacto'] ?? '';
          _emergenciaTelefonoController.text = datos['emergencia_telefono'] ?? '';
          _isLoading = false;
        });
        print("✅ Estado actualizado correctamente desde usuario-app");
      } else {
        print("❌ No se encontraron datos del conductor");
        setState(() {
          _isLoading = false;
        });
        _mostrarSnackBar('No se encontraron datos del conductor', esError: true);
      }
    } catch (e) {
      print("❌ Error al cargar datos: $e");
      setState(() {
        _isLoading = false;
      });
      _mostrarSnackBar('Error al cargar datos: $e', esError: true);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final datosActualizados = {
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'placa_vehiculo': _placaVehiculoController.text.trim(),
        'modelo_vehiculo': _modeloVehiculoController.text.trim(),
        'licencia_categoria': _licenciaCategoriaController.text.trim(),
        'comentarios_adicionales': _comentariosAdicionalesController.text.trim(),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      };

      // Si existe en solicitudes_conductores, actualizar ahí
      if (_datosUsuario.containsKey('estado')) {
        final solicitudQuery = await FirebaseFirestore.instance
            .collection('solicitudes_conductores')
            .where('email', isEqualTo: user!.email)
            .limit(1)
            .get();
            
        if (solicitudQuery.docs.isNotEmpty) {
          await solicitudQuery.docs.first.reference.update(datosActualizados);
        }
      } else {
        // Actualizar en usuario-app
        await FirebaseFirestore.instance
            .collection('usuario-app')
            .doc(user!.uid)
            .update(datosActualizados);
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
        _datosUsuario.addAll(datosActualizados);
      });

      _mostrarSnackBar('¡Perfil de conductor actualizado correctamente!');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarSnackBar('Error al guardar: $e', esError: true);
    }
  }

  Future<void> _cambiarPasswordConValidacion() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      print("🔍 Iniciando proceso de cambio de contraseña...");
      
      // Obtener la contraseña actual de Firestore
      DocumentSnapshot userDoc;
      if (_documentId != null && !_datosUsuario.containsKey('estado')) {
        userDoc = await FirebaseFirestore.instance
            .collection('usuario-app')
            .doc(_documentId!)
            .get();
      } else {
        final query = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
            
        if (query.docs.isEmpty) {
          throw Exception('No se encontró el documento del usuario');
        }
        userDoc = query.docs.first;
      }
      
      if (!userDoc.exists) {
        throw Exception('Documento del usuario no existe');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final passwordEnFirestore = userData['password']?.toString() ?? '';
      
      // Validar contraseña actual
      if (passwordEnFirestore.isEmpty) {
        throw Exception('No se encontró contraseña en la base de datos');
      }
      
      if (_passwordActualController.text.trim() != passwordEnFirestore) {
        setState(() {
          _isLoading = false;
        });
        _mostrarSnackBar('❌ La contraseña actual es incorrecta', esError: true);
        _passwordActualController.clear();
        return;
      }
      
      // Validar nueva contraseña
      if (_passwordNuevaController.text.trim().length < 6) {
        setState(() {
          _isLoading = false;
        });
        _mostrarSnackBar('❌ La nueva contraseña debe tener al menos 6 caracteres', esError: true);
        return;
      }
      
      if (_passwordNuevaController.text.trim() == passwordEnFirestore) {
        setState(() {
          _isLoading = false;
        });
        _mostrarSnackBar('❌ La nueva contraseña debe ser diferente a la actual', esError: true);
        return;
      }
      
      // Actualizar contraseña en Firestore
      final datosActualizados = {
        'password': _passwordNuevaController.text.trim(),
        'fecha_actualizacion_password': FieldValue.serverTimestamp(),
        'password_anterior': passwordEnFirestore,
      };
      
      await userDoc.reference.update(datosActualizados);
      
      // Limpiar formulario
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _passwordConfirmarController.clear();
      
      setState(() {
        _isLoading = false;
        _isChangingPassword = false;
        _datosUsuario['password'] = _passwordNuevaController.text.trim();
      });
      
      _mostrarSnackBar('🎉 ¡Contraseña actualizada correctamente!');
      
    } catch (e) {
      print("❌ Error en el proceso: $e");
      setState(() {
        _isLoading = false;
      });
      
      String mensaje = 'Error al cambiar contraseña: $e';
      if (e.toString().contains('No se encontró')) {
        mensaje = '❌ No se pudo acceder a los datos del usuario';
      }
      
      _mostrarSnackBar(mensaje, esError: true);
    }
  }

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? errorColor : successColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    try {
      final fechaSeleccionada = await showDatePicker(
        context: context,
        initialDate: DateTime.now().subtract(Duration(days: 6570)),
        firstDate: DateTime(1950),
        lastDate: DateTime.now(),
        helpText: 'Seleccionar fecha de nacimiento',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
        fieldLabelText: 'Fecha de nacimiento',
        fieldHintText: 'dd/mm/aaaa',
      );

      if (fechaSeleccionada != null) {
        setState(() {
          _fechaNacimientoController.text = 
              DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
        });
      }
    } catch (e) {
      print("Error al seleccionar fecha: $e");
      _mostrarSnackBar('Error al seleccionar fecha', esError: true);
    }
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icono,
    TextInputType tipo = TextInputType.text,
    bool esRequerido = false,
    bool soloLectura = false,
    VoidCallback? onTap,
    int maxLineas = 1,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        readOnly: !_isEditing || soloLectura,
        onTap: onTap,
        maxLines: maxLineas,
        validator: esRequerido ? (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Este campo es requerido';
          }
          return null;
        } : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icono, color: conductorColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: conductorColor, width: 2),
          ),
          filled: true,
          fillColor: _isEditing ? Colors.white : Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildCampoPassword({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool mostrarPassword,
    required VoidCallback togglePassword,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: !mostrarPassword,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(Icons.lock, color: conductorColor),
          suffixIcon: IconButton(
            onPressed: togglePassword,
            icon: Icon(
              mostrarPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[600],
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: conductorColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSeccionPerfil() {
    Color estadoColor;
    String estadoTexto;
    IconData estadoIcono;
    
    switch (_estadoSolicitud.toLowerCase()) {
      case 'aprobado':
        estadoColor = successColor;
        estadoTexto = 'Aprobado';
        estadoIcono = Icons.check_circle;
        break;
      case 'rechazado':
        estadoColor = errorColor;
        estadoTexto = 'Rechazado';
        estadoIcono = Icons.cancel;
        break;
      default:
        estadoColor = warningColor;
        estadoTexto = 'Pendiente';
        estadoIcono = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: conductorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.drive_eta,
                  size: 40,
                  color: conductorColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datosUsuario['nombre'] ?? _datosUsuario['name'] ?? 'Conductor',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _datosUsuario['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: conductorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Conductor',
                        style: TextStyle(
                          color: conductorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Estado de la solicitud
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: estadoColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(estadoIcono, size: 20, color: estadoColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estado de solicitud: $estadoTexto',
                        style: TextStyle(
                          color: estadoColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_testPsicotecnicoAprobado) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.psychology, size: 16, color: successColor),
                      const SizedBox(width: 4),
                      Text(
                        'Test Psicotécnico Aprobado',
                        style: TextStyle(
                          color: successColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Información del vehículo
          if (_placaVehiculoController.text.isNotEmpty || _modeloVehiculoController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_modeloVehiculoController.text} - ${_placaVehiculoController.text}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Licencia: ${_licenciaCategoriaController.text.isEmpty ? 'Sin categoría' : _licenciaCategoriaController.text}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return 'No disponible';
    
    try {
      if (fecha is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(fecha.toDate());
      } else if (fecha is String) {
        return fecha;
      }
      return 'No disponible';
    } catch (e) {
      return 'No disponible';
    }
  }

  Widget _buildFormularioDatos() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: conductorColor),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Editando Perfil del Conductor' : 'Información del Conductor',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Información Personal
            Text(
              'Información Personal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: conductorColor,
              ),
            ),
            
            const SizedBox(height: 12),
            
            _buildCampoTexto(
              controller: _nombreController,
              label: 'Nombre Completo',
              hint: 'Ingresa tu nombre completo',
              icono: Icons.person,
              esRequerido: true,
            ),
            
            _buildCampoTexto(
              controller: _emailController,
              label: 'Correo Electrónico',
              hint: 'tu@email.com',
              icono: Icons.email,
              tipo: TextInputType.emailAddress,
              esRequerido: true,
            ),
            
            _buildCampoTexto(
              controller: _telefonoController,
              label: 'Teléfono',
              hint: '+591 70000000',
              icono: Icons.phone,
              tipo: TextInputType.phone,
              esRequerido: true,
            ),
            
            _buildCampoTexto(
              controller: _direccionController,
              label: 'Dirección',
              hint: 'Tu dirección completa',
              icono: Icons.location_on,
              maxLineas: 2,
            ),
            
            const SizedBox(height: 20),
            
            // Información del Vehículo
            Row(
              children: [
                Icon(Icons.directions_car, color: conductorColor),
                const SizedBox(width: 8),
                Text(
                  'Información del Vehículo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: conductorColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildCampoTexto(
              controller: _placaVehiculoController,
              label: 'Placa del Vehículo',
              hint: 'Ej: 1234ABC',
              icono: Icons.confirmation_number,
              esRequerido: true,
            ),
            
            _buildCampoTexto(
              controller: _modeloVehiculoController,
              label: 'Modelo del Vehículo',
              hint: 'Ej: Toyota Corolla 2020',
              icono: Icons.car_rental,
              esRequerido: true,
            ),
            
            _buildCampoTexto(
              controller: _licenciaCategoriaController,
              label: 'Categoría de Licencia',
              hint: 'Ej: B, C, D',
              icono: Icons.badge,
              esRequerido: true,
            ),
            
            const SizedBox(height: 20),
            
            // Comentarios adicionales
            Row(
              children: [
                Icon(Icons.comment, color: conductorColor),
                const SizedBox(width: 8),
                Text(
                  'Información Adicional',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: conductorColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildCampoTexto(
              controller: _comentariosAdicionalesController,
              label: 'Comentarios Adicionales',
              hint: 'Información adicional relevante...',
              icono: Icons.notes,
              maxLineas: 3,
            ),
            
            const SizedBox(height: 20),
            
            // Contacto de Emergencia
            Row(
              children: [
                Icon(Icons.emergency, color: errorColor),
                const SizedBox(width: 8),
                Text(
                  'Contacto de Emergencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: errorColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildCampoTexto(
              controller: _emergenciaContactoController,
              label: 'Nombre del Contacto',
              hint: 'Familiar o amigo cercano',
              icono: Icons.contact_emergency,
            ),
            
            _buildCampoTexto(
              controller: _emergenciaTelefonoController,
              label: 'Teléfono de Emergencia',
              hint: '+591 70000000',
              icono: Icons.contact_phone,
              tipo: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioPassword() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: warningColor),
                const SizedBox(width: 8),
                Text(
                  'Cambiar Contraseña',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: warningColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: warningColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tu nueva contraseña debe tener al menos 6 caracteres',
                          style: TextStyle(
                            color: warningColor.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Asegúrate de ingresar tu contraseña actual correctamente',
                          style: TextStyle(
                            color: Colors.blue.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildCampoPassword(
              controller: _passwordActualController,
              label: 'Contraseña Actual',
              hint: 'Ingresa tu contraseña actual',
              mostrarPassword: _showCurrentPassword,
              togglePassword: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña actual';
                }
                return null;
              },
            ),
            
            _buildCampoPassword(
              controller: _passwordNuevaController,
              label: 'Nueva Contraseña',
              hint: 'Ingresa tu nueva contraseña',
              mostrarPassword: _showNewPassword,
              togglePassword: () => setState(() => _showNewPassword = !_showNewPassword),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa una nueva contraseña';
                }
                if (value.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres';
                }
                return null;
              },
            ),
            
            _buildCampoPassword(
              controller: _passwordConfirmarController,
              label: 'Confirmar Nueva Contraseña',
              hint: 'Confirma tu nueva contraseña',
              mostrarPassword: _showConfirmPassword,
              togglePassword: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu nueva contraseña';
                }
                if (value != _passwordNuevaController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _isChangingPassword = false;
                      });
                      _passwordActualController.clear();
                      _passwordNuevaController.clear();
                      _passwordConfirmarController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _cambiarPasswordConValidacion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: warningColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Cambiar Contraseña',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstadisticas() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: conductorColor),
              const SizedBox(width: 8),
              Text(
                'Estadísticas del Conductor',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // StreamBuilder para obtener datos reales de Firebase
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('viajes')
                .where('conductor_id', isEqualTo: user!.uid)
                .where('estado', isEqualTo: 'finalizado')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: conductorColor),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Text(
                    'Error al cargar estadísticas',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              final viajes = snapshot.data!.docs;
              
              // Calcular estadísticas reales
              final totalViajes = viajes.length;
              
              // Calcular calificación promedio
              double promedioCalificacion = 0.0;
              int totalCalificaciones = 0;
              
              for (var viaje in viajes) {
                final data = viaje.data() as Map<String, dynamic>;
                final calificacionGeneral = data['calificacion_general'] ?? 0;
                if (calificacionGeneral > 0) {
                  promedioCalificacion += calificacionGeneral;
                  totalCalificaciones++;
                }
              }
              
              if (totalCalificaciones > 0) {
                promedioCalificacion = promedioCalificacion / totalCalificaciones;
              }
              
              // Calcular puntualidad (viajes con calificación de puntualidad >= 4)
              int viajesPuntuales = 0;
              int viajesConCalificacionPuntualidad = 0;
              
              for (var viaje in viajes) {
                final data = viaje.data() as Map<String, dynamic>;
                final calificacionPuntualidad = data['calificacion_puntualidad'] ?? 0;
                if (calificacionPuntualidad > 0) {
                  viajesConCalificacionPuntualidad++;
                  if (calificacionPuntualidad >= 4) {
                    viajesPuntuales++;
                  }
                }
              }
              
              double porcentajePuntualidad = 0.0;
              if (viajesConCalificacionPuntualidad > 0) {
                porcentajePuntualidad = (viajesPuntuales / viajesConCalificacionPuntualidad) * 100;
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: successColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.star, color: successColor, size: 20),
                              const SizedBox(height: 6),
                              Text(
                                totalCalificaciones > 0 
                                  ? promedioCalificacion.toStringAsFixed(1)
                                  : '0.0',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: successColor,
                                ),
                              ),
                              Text(
                                'Calificación',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: successColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '($totalCalificaciones)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: successColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.route, color: primaryColor, size: 20),
                              const SizedBox(height: 6),
                              Text(
                                '$totalViajes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'Viajes',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Completados',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: primaryColor.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: warningColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.schedule, color: warningColor, size: 20),
                              const SizedBox(height: 6),
                              Text(
                                viajesConCalificacionPuntualidad > 0 
                                  ? '${porcentajePuntualidad.toStringAsFixed(0)}%'
                                  : '0%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: warningColor,
                                ),
                              ),
                              Text(
                                'Puntualidad',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: warningColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '($viajesPuntuales/$viajesConCalificacionPuntualidad)',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: warningColor.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Información adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Las estadísticas se actualizan automáticamente con cada viaje completado',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _isEditing = false;
                      });
                      _cargarDatosConductor();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardarCambios,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: conductorColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Editar Perfil de Conductor',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isChangingPassword = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: warningColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, color: warningColor),
                    const SizedBox(width: 8),
                    Text(
                      'Cambiar Contraseña',
                      style: TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Botón para solicitar verificación si está pendiente
            if (_estadoSolicitud.toLowerCase() == 'pendiente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _mostrarSnackBar('Solicitud de verificación enviada. Recibirás una notificación cuando sea procesada.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Solicitar Verificación',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Usuario no autenticado"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isChangingPassword ? "Cambiar Contraseña" : "Perfil del Conductor",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: _isChangingPassword,
        leading: _isChangingPassword 
          ? IconButton(
              onPressed: () {
                setState(() {
                  _isChangingPassword = false;
                });
                _passwordActualController.clear();
                _passwordNuevaController.clear();
                _passwordConfirmarController.clear();
              },
              icon: Icon(Icons.arrow_back),
            )
          : null,
        actions: [
          if (!_isEditing && !_isChangingPassword)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: Icon(Icons.edit, color: conductorColor),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: CircularProgressIndicator(color: conductorColor),
          )
        : _isChangingPassword
          ? ListView(
              children: [
                _buildFormularioPassword(),
                const SizedBox(height: 20),
              ],
            )
          : ListView(
              children: [
                _buildSeccionPerfil(),
                if (_estadoSolicitud.toLowerCase() == 'aprobado')
                  _buildSeccionEstadisticas(),
                _buildFormularioDatos(),
                _buildBotones(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}