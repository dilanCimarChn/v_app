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
  
  // Controladores para los campos
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _emergenciaContactoController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();
  
  // Estados
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic> _datosUsuario = {};
  
  // Colores
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);

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
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuario-app')
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        final datos = doc.data() as Map<String, dynamic>;
        setState(() {
          _datosUsuario = datos;
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
      }
    } catch (e) {
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

      await FirebaseFirestore.instance
          .collection('usuario-app')
          .doc(user!.uid)
          .update(datosActualizados);

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
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 6570)), // 18 años
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaNacimientoController.text = 
            DateFormat('dd/MM/yyyy').format(fechaSeleccionada);
      });
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
          // Avatar y nombre
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
          
          // Información de registro
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
                Text(
                  'Miembro desde: ${_formatearFecha(_datosUsuario['fecha_registro'])}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
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
                    fontSize: 12,
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
            
            // Datos básicos
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
            
            // Contacto de emergencia
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

  Widget _buildBotones() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: _isEditing 
        ? Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isEditing = false;
                    });
                    _cargarDatosUsuario(); // Recargar datos originales
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
          )
        : SizedBox(
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
        title: const Text(
          "Mi Perfil",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          if (!_isEditing)
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
        : ListView(
            children: [
              // Sección del perfil
              _buildSeccionPerfil(),
              
              // Formulario de datos
              _buildFormularioDatos(),
              
              // Botones
              _buildBotones(),
              
              const SizedBox(height: 20),
            ],
          ),
    );
  }
}