import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:v_app/services/openrouteservice_api.dart';

class MapaConductorWidget extends StatefulWidget {
  const MapaConductorWidget({super.key});

  @override
  State<MapaConductorWidget> createState() => _MapaConductorWidgetState();
}

class _MapaConductorWidgetState extends State<MapaConductorWidget> {
  MaplibreMapController? mapController;
  LatLng? ubicacionConductor;
  StreamSubscription? _viajeSubscription;
  Symbol? origenSymbol;
  Symbol? destinoSymbol;
  Line? rutaLine;
  Map<String, dynamic>? viajeActivo;
  String? idViaje;
  bool viajeIniciado = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
    _escucharViajesPendientes();
  }

  @override
  void dispose() {
    _viajeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    var status = await Permission.location.request();
    if (status != PermissionStatus.granted || !await Geolocator.isLocationServiceEnabled()) return;
    Position posicion = await Geolocator.getCurrentPosition();
    setState(() {
      ubicacionConductor = LatLng(posicion.latitude, posicion.longitude);
    });
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    if (ubicacionConductor != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(ubicacionConductor!, 15));
      controller.addSymbol(SymbolOptions(
        geometry: ubicacionConductor!,
        iconImage: "marker-15",
        iconSize: 1.5,
      ));
    }
  }

  void _escucharViajesPendientes() {
    _viajeSubscription = FirebaseFirestore.instance
        .collection('viajes')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        _mostrarModalAceptacion(doc);
      }
    });
  }

  void _mostrarModalAceptacion(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final origen = LatLng(data['origen_lat'], data['origen_lng']);
    final destino = LatLng(data['destino_lat'], data['destino_lng']);

    final rawDistancia = data['distancia_km'];
    final rawTarifa = data['tarifa'];
    final double distancia = (rawDistancia is num) ? rawDistancia.toDouble() : 0.0;
    final double tarifa = (rawTarifa is num) ? rawTarifa.toDouble() : 0.0;

    final user = FirebaseAuth.instance.currentUser;
    final conductorId = user?.uid;
    String conductorNombre = '';

    if (user != null) {
      final conductorQuery = await FirebaseFirestore.instance
          .collection('usuario-app')
          .where('email', isEqualTo: user.email)
          .where('rol', isEqualTo: 'conductor')
          .get();

      if (conductorQuery.docs.isNotEmpty) {
        conductorNombre = conductorQuery.docs.first.data()['name'] ?? 'Conductor';
      }
    }

    final clienteId = data['cliente_id'];
    String clienteNombre = 'Cliente';

    final clienteDoc = await FirebaseFirestore.instance.collection('usuario-app').doc(clienteId).get();
    if (clienteDoc.exists) {
      clienteNombre = clienteDoc.data()?['name'] ?? 'Cliente';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(" Nuevo viaje disponible"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Cliente: $clienteNombre"),
            Text("Conductor: $conductorNombre"),
            Text("Distancia: ${distancia.toStringAsFixed(2)} km"),
            Text("Tarifa: Bs. ${tarifa.toStringAsFixed(2)}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Rechazar"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('viajes').doc(doc.id).update({
                'estado': 'aceptado',
                'conductor_id': conductorId,
                'conductor_nombre': conductorNombre,
                'cliente_nombre': clienteNombre,
                'distancia_km': distancia,
                'tarifa': tarifa,
              });
              Navigator.pop(context);
              setState(() {
                viajeActivo = {
                  ...data,
                  'conductor_nombre': conductorNombre,
                  'cliente_nombre': clienteNombre,
                  'distancia_km': distancia,
                  'tarifa': tarifa,
                };
                idViaje = doc.id;
              });
              _mostrarRutaAlCliente(origen);
            },
            child: const Text("Aceptar viaje"),
          )
        ],
      ),
    );
  }

  Future<void> _mostrarRutaAlCliente(LatLng clienteOrigen) async {
    if (ubicacionConductor == null || mapController == null) return;

    final puntos = await OpenRouteServiceAPI.obtenerRuta(
      origen: ubicacionConductor!,
      destino: clienteOrigen,
    );

    mapController!.clearLines();
    mapController!.clearSymbols();
    origenSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: clienteOrigen,
      iconImage: "marker-15",
      iconSize: 1.5,
    ));

    rutaLine = await mapController!.addLine(LineOptions(
      geometry: puntos,
      lineColor: "#007AFF",
      lineWidth: 5,
    ));
  }

  Future<void> _iniciarViaje() async {
    if (viajeActivo == null || idViaje == null) return;

    final destino = LatLng(viajeActivo!['destino_lat'], viajeActivo!['destino_lng']);
    final puntos = await OpenRouteServiceAPI.obtenerRuta(
      origen: ubicacionConductor!,
      destino: destino,
    );

    mapController!.clearLines();
    mapController!.clearSymbols();
    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: destino,
      iconImage: "marker-15",
      iconSize: 1.5,
    ));

    await mapController!.addLine(LineOptions(
      geometry: puntos,
      lineColor: "#00C851",
      lineWidth: 5,
    ));

    await FirebaseFirestore.instance.collection('viajes').doc(idViaje!).update({
      'estado': 'en_curso',
    });

    setState(() {
      viajeIniciado = true;
    });
  }

  Future<void> _cancelarViaje() async {
    if (idViaje == null) return;

    await FirebaseFirestore.instance.collection('viajes').doc(idViaje!).update({
      'estado': 'cancelado',
    });

    setState(() {
      viajeActivo = null;
      idViaje = null;
      viajeIniciado = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(' Viaje cancelado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ubicacionConductor == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              MaplibreMap(
                styleString: "https://api.maptiler.com/maps/outdoor-v2/style.json?key=Y2TaDOuaHgeijPZP0ZiP",
                initialCameraPosition: CameraPosition(
                  target: ubicacionConductor!,
                  zoom: 14.0,
                ),
                onMapCreated: _onMapCreated,
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.tracking,
              ),
              if (viajeActivo != null)
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cliente: ${viajeActivo!['cliente_nombre'] ?? 'Cliente'}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("Conductor: ${viajeActivo!['conductor_nombre'] ?? 'Conductor'}"),
                      Text("Distancia: ${viajeActivo!['distancia_km']?.toStringAsFixed(2) ?? '0.00'} km"),
                      Text("Tarifa: Bs. ${viajeActivo!['tarifa']?.toStringAsFixed(2) ?? '0.00'}"),
                    ],
                  ),
                ),
              if (viajeActivo != null)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: viajeIniciado ? _cancelarViaje : _iniciarViaje,
                    icon: Icon(viajeIniciado ? Icons.cancel : Icons.play_arrow),
                    label: Text(viajeIniciado ? "Cancelar viaje" : "Iniciar viaje"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: viajeIniciado ? Colors.red : Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
            ],
          );
  }
}
