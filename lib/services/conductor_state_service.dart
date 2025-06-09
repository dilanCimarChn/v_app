// Reemplaza TEMPORALMENTE el contenido de conductor_state_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class ConductorStateService {
  static final ConductorStateService _instance = ConductorStateService._internal();
  factory ConductorStateService() => _instance;
  ConductorStateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();

  String? _conductorId = 'TxMEX6ifhGjQAQfWLmsY'; // Hardcoded para testing
  bool _isActive = false;

  // Getters
  String? get conductorId => _conductorId;
  bool get isActive => _isActive;

  // Inicializar servicio - VERSION SIMPLIFICADA
  Future<bool> initialize() async {
    try {
      print('🔄 Inicializando ConductorStateService...');
      
      // Solo cargar estado local por ahora
      final prefs = await SharedPreferences.getInstance();
      _isActive = prefs.getBool('conductor_active') ?? false;
      
      print('✅ Servicio inicializado. Estado: $_isActive, ID: $_conductorId');
      return true;
    } catch (e) {
      print('❌ Error inicializando ConductorStateService: $e');
      return false;
    }
  }

  // Cambiar estado del conductor - VERSION SIMPLIFICADA
  Future<bool> toggleActiveState() async {
    print('🔄 === INICIO toggleActiveState SIMPLE ===');
    
    try {
      final newState = !_isActive;
      print('🔄 Cambiando de $_isActive a $newState');

      // SOLO manejar ubicación por ahora
      if (newState) {
        print('🔄 Activando conductor - iniciando rastreo...');
        final success = await _locationService.startLocationTracking(_conductorId!);
        print('🔄 Resultado rastreo: $success');
        
        if (!success) {
          print('❌ Error iniciando rastreo');
          return false;
        }
      } else {
        print('🔄 Desactivando conductor - deteniendo rastreo...');
        await _locationService.stopLocationTracking(_conductorId!);
        print('✅ Rastreo detenido');
      }

      // Actualizar estado local
      _isActive = newState;
      
      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('conductor_active', _isActive);
      
      print('✅ Estado local cambiado a: $_isActive');

      // INTENTAR actualizar Firebase (sin fallar si no funciona)
      try {
        await _updateStateInFirebase(newState);
        print('✅ Firebase actualizado exitosamente');
      } catch (e) {
        print('⚠️ Error actualizando Firebase (continuando): $e');
        // No fallar aquí, continuar de todas formas
      }

      print('🔄 === FIN toggleActiveState SUCCESS ===');
      return true;

    } catch (e) {
      print('❌ ERROR en toggleActiveState: $e');
      return false;
    }
  }

  // Actualizar estado en Firebase
  Future<void> _updateStateInFirebase(bool isActive) async {
    try {
      print('🔄 Intentando actualizar Firebase...');
      print('🔄 Conductor ID: $_conductorId');
      print('🔄 Nuevo estado: ${isActive ? 'activo' : 'inactivo'}');
      
      // Verificar que tenemos ID
      if (_conductorId == null || _conductorId!.isEmpty) {
        throw Exception('ID de conductor no válido: $_conductorId');
      }
      
      // Primero verificar si el documento existe
      final usuarioRef = _firestore.collection('usuario-app').doc(_conductorId);
      
      print('🔄 Verificando si documento existe...');
      final doc = await usuarioRef.get();
      
      if (doc.exists) {
        print('✅ Documento existe, actualizando...');
        // Documento existe, usar update
        await usuarioRef.update({
          'estado_disponibilidad': isActive ? 'activo' : 'inactivo',
          'ultima_actividad': FieldValue.serverTimestamp(),
        });
        print('✅ Update exitoso');
      } else {
        print('🔄 Documento no existe, creando...');
        // Documento no existe, crear con set
        await usuarioRef.set({
          'email': 'bolchiquel1@gmail.com',
          'name': 'Anders Guitars',
          'rol': 'conductor',
          'estado_disponibilidad': isActive ? 'activo' : 'inactivo',
          'ultima_actividad': FieldValue.serverTimestamp(),
          'telefono': '',
          'fecha_registro': FieldValue.serverTimestamp(),
          'viajes_completados': 0,
          'licenciaURL': 'BaseLic'
        });
        print('✅ Set exitoso');
      }

      // Verificar que se actualizó
      print('🔄 Verificando actualización...');
      final updatedDoc = await usuarioRef.get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data() as Map<String, dynamic>;
        final currentState = data['estado_disponibilidad'];
        print('✅ Estado en Firebase: $currentState');
        
        if (currentState == (isActive ? 'activo' : 'inactivo')) {
          print('✅ ¡Firebase actualizado correctamente!');
        } else {
          print('⚠️ El estado en Firebase no coincide. Esperado: ${isActive ? 'activo' : 'inactivo'}, Actual: $currentState');
        }
      } else {
        print('❌ Documento no encontrado después de la actualización');
      }

    } catch (e) {
      print('❌ Error detallado en Firebase: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Código Firebase: ${e.code}');
        print('❌ Mensaje Firebase: ${e.message}');
      }
      throw e;
    }
  }

  // Stream para escuchar cambios de estado
  Stream<bool> getStateStream() {
    return Stream.value(_isActive);
  }

  // Limpiar recursos
  void dispose() {
    _locationService.dispose();
  }
}