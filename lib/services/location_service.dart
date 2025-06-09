import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isTracking = false;

  // Verificar y solicitar permisos de ubicación
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Iniciar rastreo de ubicación
  Future<bool> startLocationTracking(String conductorId) async {
    if (_isTracking) {
      print('Ya se está rastreando la ubicación');
      return true;
    }

    try {
      // Verificar permisos
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Permisos de ubicación denegados');
      }

      // Obtener posición inicial
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Actualizar posición inicial
      await updatePositionInFirebase(conductorId, currentPosition);

      // Configurar stream de ubicación
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          updatePositionInFirebase(conductorId, position);
        },
        onError: (error) {
          print('Error en stream de ubicación: $error');
        },
      );

      // Timer para actualizaciones periódicas (cada 30 segundos)
      _locationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (timer) async {
          try {
            Position position = await Geolocator.getCurrentPosition();
            await updatePositionInFirebase(conductorId, position);
          } catch (e) {
            print('Error en actualización periódica: $e');
          }
        },
      );

      _isTracking = true;
      print('Rastreo de ubicación iniciado para conductor: $conductorId');
      return true;

    } catch (e) {
      print('Error iniciando rastreo de ubicación: $e');
      return false;
    }
  }

  // Detener rastreo de ubicación
  Future<void> stopLocationTracking(String conductorId) async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _locationTimer?.cancel();
    _locationTimer = null;

    _isTracking = false;

    // Marcar como no disponible en Firebase
    try {
      await _firestore
          .collection('posiciones_conductores')
          .doc(conductorId)
          .update({
        'disponible': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizando estado final: $e');
    }

    print('Rastreo de ubicación detenido para conductor: $conductorId');
  }

  // Actualizar posición en Firebase
  Future<void> updatePositionInFirebase(String conductorId, Position position) async {
    try {
      final batch = _firestore.batch();

      // Actualizar en posiciones_conductores
      final posicionRef = _firestore
          .collection('posiciones_conductores')
          .doc(conductorId);

      batch.set(posicionRef, {
        'conductor_id': conductorId,
        'lat': position.latitude,
        'lng': position.longitude,
        'velocidad': position.speed * 3.6, // Convertir m/s a km/h
        'precision': position.accuracy,
        'disponible': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Actualizar en usuario-app
      final usuarioRef = _firestore
          .collection('usuario-app')
          .doc(conductorId);

      batch.update(usuarioRef, {
        'ubicacion_actual': {
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'ultima_actividad': FieldValue.serverTimestamp(),
      });

      await batch.commit();

    } catch (e) {
      print('Error actualizando posición en Firebase: $e');
    }
  }

  // Obtener posición actual
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error obteniendo posición actual: $e');
      return null;
    }
  }

  // Verificar si se está rastreando
  bool get isTracking => _isTracking;

  // Limpiar recursos
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationTimer?.cancel();
  }
}