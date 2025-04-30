import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uuid/uuid.dart';

final _firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

Future<void> crearViajeEnFirebase({
  required LatLng origen,
  required LatLng destino,
}) async {
  final user = _auth.currentUser;
  if (user == null) {
    print('⚠️ Usuario no autenticado');
    return;
  }

  final String clienteId = user.uid;
  final String viajeId = const Uuid().v4();

  final double distanciaKm = calcularDistanciaKm(origen, destino);
  final double tarifa = calcularTarifa(distanciaKm);
  final int tiempoEstimado = (distanciaKm * 2).round(); // Ejemplo: 2 min/km

  final Map<String, dynamic> data = {
    'cliente_id': clienteId,
    'conductor_id': null,
    'origen_lat': origen.latitude,
    'origen_lng': origen.longitude,
    'destino_lat': destino.latitude,
    'destino_lng': destino.longitude,
    'estado': 'pendiente',
    'distancia_km': distanciaKm,
    'tarifa': tarifa,
    'tiempo_estimado': tiempoEstimado,
    'fecha_inicio': DateTime.now(), // se verá de inmediato
    'fecha_creacion': FieldValue.serverTimestamp(), // para orden en server
  };

  try {
    await _firestore.collection('viajes').doc(viajeId).set(data);
    print('✅ Viaje creado correctamente en Firebase con ID: $viajeId');
  } catch (e) {
    print('❌ Error al guardar viaje: $e');
  }
}

double calcularDistanciaKm(LatLng origen, LatLng destino) {
  final double lat1 = origen.latitude;
  final double lon1 = origen.longitude;
  final double lat2 = destino.latitude;
  final double lon2 = destino.longitude;

  const double radioTierra = 6371;

  final double dLat = _gradosARadianes(lat2 - lat1);
  final double dLon = _gradosARadianes(lon2 - lon1);

  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_gradosARadianes(lat1)) *
          cos(_gradosARadianes(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return radioTierra * c;
}

double calcularTarifa(double distanciaKm) {
  const double precioBase = 5.0;
  const double precioPorKm = 3.5;
  return precioBase + (distanciaKm * precioPorKm);
}

double _gradosARadianes(double grados) {
  return grados * (pi / 180);
}
