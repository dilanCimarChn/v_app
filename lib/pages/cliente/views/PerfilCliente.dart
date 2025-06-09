import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PerfilCliente extends StatefulWidget {
  const PerfilCliente({super.key});

  @override
  State<PerfilCliente> createState() => _PerfilClienteState();
}

class _PerfilClienteState extends State<PerfilCliente> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  // Controladores para los campos
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _emergenciaContactoController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();
  
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
  
  // Colores
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
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
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    print("🔍 Iniciando carga de datos...");
    
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
      print("🔍 Buscando documento en usuario-app...");
      
      final doc = await FirebaseFirestore.instance
          .collection('usuario-app')
          .doc(user!.uid)
          .get();
      
      print("📄 Documento existe: ${doc.exists}");
      
      if (doc.exists) {
        final datos = doc.data() as Map<String, dynamic>;
        print("📊 Datos encontrados: $datos");
        
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
        print("✅ Estado actualizado correctamente");
      } else {
        print("❌ Documento no existe, buscando por email...");
        
        final query = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user!.email)
            .get();
            
        print("📊 Documentos encontrados por email: ${query.docs.length}");
        
        if (query.docs.isNotEmpty) {
          final datos = query.docs.first.data();
          print("📊 Datos por email: $datos");
          
          setState(() {
            _datosUsuario = datos;
            _documentId = query.docs.first.id;
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
        } else {
          print("❌ No se encontraron datos del usuario");
          setState(() {
            _isLoading = false;
          });
          _mostrarSnackBar('No se encontraron datos del usuario', esError: true);
        }
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
        'name': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'fecha_nacimiento': _fechaNacimientoController.text.trim(),
        'cedula': _cedulaController.text.trim(),
        'emergencia_contacto': _emergenciaContactoController.text.trim(),
        'emergencia_telefono': _emergenciaTelefonoController.text.trim(),
        'perfil_completado': true,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      };

      if (_documentId != null) {
        await FirebaseFirestore.instance
            .collection('usuario-app')
            .doc(_documentId!)
            .update(datosActualizados);
      } else {
        final query = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user!.email)
            .limit(1)
            .get();
            
        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.update(datosActualizados);
        } else {
          throw Exception('No se encontró el documento del usuario');
        }
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
        _datosUsuario.addAll(datosActualizados);
      });

      _mostrarSnackBar('¡Perfil actualizado correctamente!');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarSnackBar('Error al guardar: $e', esError: true);
    }
  }

  Future<void> _verificarPasswordActual() async {
    if (_passwordActualController.text.trim().isEmpty) {
      _mostrarSnackBar('Ingresa tu contraseña actual primero', esError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordActualController.text.trim(),
      );
      
      await user.reauthenticateWithCredential(credential);
      
      setState(() {
        _isLoading = false;
      });
      
      _mostrarSnackBar('✅ Contraseña actual verificada correctamente');
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _mostrarSnackBar('❌ La contraseña actual es incorrecta', esError: true);
      } else {
        _mostrarSnackBar('Error: ${e.message}', esError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarSnackBar('Error: $e', esError: true);
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      print("🔍 Intentando cambiar contraseña para: ${user.email}");
      print("🔍 Contraseña actual ingresada: ${_passwordActualController.text.isNotEmpty ? 'Sí' : 'No'}");
      print("🔍 Longitud contraseña actual: ${_passwordActualController.text.length}");

      // Crear las credenciales para reautenticación
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordActualController.text.trim(),
      );
      
      print("🔐 Intentando reautenticar...");
      
      // Reautenticar usuario con contraseña actual
      await user.reauthenticateWithCredential(credential);
      
      print("✅ Reautenticación exitosa");
      
      // Cambiar contraseña
      await user.updatePassword(_passwordNuevaController.text.trim());
      
      print("✅ Contraseña actualizada exitosamente");
      
      // Limpiar formulario
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _passwordConfirmarController.clear();
      
      setState(() {
        _isLoading = false;
        _isChangingPassword = false;
      });
      
      _mostrarSnackBar('¡Contraseña actualizada correctamente!');
      
    } on FirebaseAuthException catch (e) {
      print("❌ FirebaseAuthException: ${e.code} - ${e.message}");
      
      setState(() {
        _isLoading = false;
      });
      
      String mensaje = 'Error al cambiar contraseña';
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          mensaje = '❌ La contraseña actual es INCORRECTA.\n\n💡 Prueba:\n• Verificar mayúsculas/minúsculas\n• Sin espacios extra\n• La misma que usas para entrar a la app';
          break;
        case 'weak-password':
          mensaje = 'La nueva contraseña es muy débil. Debe tener al menos 6 caracteres.';
          break;
        case 'requires-recent-login':
          mensaje = 'Por seguridad, cierra sesión e inicia sesión nuevamente, luego intenta cambiar la contraseña.';
          break;
        case 'too-many-requests':
          mensaje = '🚫 DISPOSITIVO BLOQUEADO TEMPORALMENTE\n\n⏰ Firebase bloqueó tu dispositivo por demasiados intentos fallidos.\n\n✅ SOLUCIÓN:\n• Espera 15-30 minutos\n• O cierra la app completamente\n• Reinicia tu teléfono\n• Vuelve a intentar\n\n💡 Tu contraseña correcta debería ser: 11073458';
          break;
        case 'network-request-failed':
          mensaje = 'Sin conexión a internet. Verifica tu conexión e intenta nuevamente.';
          break;
        default:
          mensaje = 'Error: ${e.message ?? e.code}';
      }
      
      _mostrarSnackBar(mensaje, esError: true);
      
      // Si es error de credenciales, limpiar solo el campo de contraseña actual
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _passwordActualController.clear();
      }
      
    } catch (e) {
      print("❌ Error general: $e");
      setState(() {
        _isLoading = false;
      });
      _mostrarSnackBar('Error inesperado: $e', esError: true);
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
        // Removemos la línea de locale para evitar el error
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
          prefixIcon: Icon(icono, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
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
          prefixIcon: Icon(Icons.lock, color: primaryColor),
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
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),  
      ),
    );
  }

  Widget _buildSeccionPerfil() {
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datosUsuario['name'] ?? 'Usuario',
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
                        color: successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Cliente',
                        style: TextStyle(
                          color: successColor,
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
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Miembro desde: ${_formatearFecha(_datosUsuario['fecha_registro'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _datosUsuario['verificado'] == true ? Icons.verified : Icons.pending,
                  size: 16,
                  color: _datosUsuario['verificado'] == true ? successColor : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _datosUsuario['verificado'] == true ? 'Verificado' : 'Pendiente',
                  style: TextStyle(
                    color: _datosUsuario['verificado'] == true ? successColor : Colors.orange,
                    fontSize: 11, // Reducido de 12 a 11
                    fontWeight: FontWeight.w600,
                  ),
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
                Icon(Icons.edit, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Editando Perfil' : 'Información Personal',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
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
            ),
            
            _buildCampoTexto(
              controller: _direccionController,
              label: 'Dirección',
              hint: 'Tu dirección completa',
              icono: Icons.location_on,
              maxLineas: 2,
            ),
            
            _buildCampoTexto(
              controller: _fechaNacimientoController,
              label: 'Fecha de Nacimiento',
              hint: 'DD/MM/AAAA',
              icono: Icons.cake,
              soloLectura: true,
              onTap: _isEditing ? _seleccionarFecha : null,
            ),
            
            _buildCampoTexto(
              controller: _cedulaController,
              label: 'Cédula de Identidad',
              hint: 'Número de CI',
              icono: Icons.badge,
              tipo: TextInputType.number,
            ),
            
            const SizedBox(height: 20),
            
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
            
            // Botón de verificación de contraseña
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,

              ),
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
                      _cargarDatosUsuario();
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
                  backgroundColor: primaryColor,
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
                      'Editar Perfil',
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
          ],
        ],
      ),
    );
  }Future<void> _cambiarPasswordConValidacion() async {
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
      print("🔍 Usuario: ${user.email}");
      
      // PASO 1: Obtener la contraseña actual de Firestore
      print("📊 Obteniendo contraseña actual de Firestore...");
      
      DocumentSnapshot userDoc;
      if (_documentId != null) {
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
      
      print("🔐 Contraseña en Firestore: $passwordEnFirestore");
      print("🔐 Contraseña ingresada: ${_passwordActualController.text.trim()}");
      
      // PASO 2: Validar que la contraseña actual coincida
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
      
      print("✅ Contraseña actual validada correctamente");
      
      // PASO 3: Validar nueva contraseña
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
      
      print("✅ Nueva contraseña validada");
      
      // PASO 4: Actualizar contraseña en Firestore
      print("🔄 Actualizando contraseña en Firestore...");
      
      final datosActualizados = {
        'password': _passwordNuevaController.text.trim(),
        'fecha_actualizacion_password': FieldValue.serverTimestamp(),
        'password_anterior': passwordEnFirestore, // Guardamos la anterior por seguridad
      };
      
      if (_documentId != null) {
        await FirebaseFirestore.instance
            .collection('usuario-app')
            .doc(_documentId!)
            .update(datosActualizados);
      } else {
        await userDoc.reference.update(datosActualizados);
      }
      
      print("✅ Contraseña actualizada en Firestore");
      
      // PASO 5: Limpiar formulario y mostrar éxito
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _passwordConfirmarController.clear();
      
      setState(() {
        _isLoading = false;
        _isChangingPassword = false;
        // Actualizar datos locales
        _datosUsuario['password'] = _passwordNuevaController.text.trim();
      });
      
      _mostrarSnackBar('🎉 ¡Contraseña actualizada correctamente!\n\nYa puedes usar tu nueva contraseña para iniciar sesión.');
      
    } catch (e) {
      print("❌ Error en el proceso: $e");
      setState(() {
        _isLoading = false;
      });
      
      String mensaje = 'Error al cambiar contraseña: $e';
      if (e.toString().contains('No se encontró')) {
        mensaje = '❌ No se pudo acceder a los datos del usuario';
      } else if (e.toString().contains('permission')) {
        mensaje = '❌ Sin permisos para actualizar la contraseña';
      }
      
      _mostrarSnackBar(mensaje, esError: true);
    }
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
          _isChangingPassword ? "Cambiar Contraseña" : "Mi Perfil",
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
              icon: Icon(Icons.edit, color: primaryColor),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: CircularProgressIndicator(color: primaryColor),
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
                _buildFormularioDatos(),
                _buildBotones(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}