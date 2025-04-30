import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:v_app/services/firebase_service.dart';
import 'package:v_app/services/openrouteservice_api.dart';

class MapaClienteWidget extends StatefulWidget {
  const MapaClienteWidget({super.key});

  @override
  State<MapaClienteWidget> createState() => _MapaClienteWidgetState();
}

class _MapaClienteWidgetState extends State<MapaClienteWidget> {
  MaplibreMapController? mapController;
  LatLng? ubicacionActual;
  LatLng? destinoSeleccionado;
  Symbol? destinoSymbol;
  Line? rutaLine;
  Symbol? conductorSymbol;
  Line? rutaAlDestino;
  StreamSubscription? viajeListener;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> sugerencias = [];
  bool modalMostrado = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
    _escucharViajeAsignado();
  }

  @override
  void dispose() {
    viajeListener?.cancel();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    var status = await Permission.location.request();
    if (!await Geolocator.isLocationServiceEnabled()) return;
    if (status != PermissionStatus.granted) return;

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      ubicacionActual = LatLng(posicion.latitude, posicion.longitude);
    });
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;

    if (ubicacionActual != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(ubicacionActual!, 15),
      );
      controller.addSymbol(SymbolOptions(
        geometry: ubicacionActual!,
        iconImage: "marker-15",
        iconSize: 1.5,
      ));
    }
  }

  void _escucharViajeAsignado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clienteId = user.uid;

    viajeListener = FirebaseFirestore.instance
        .collection('viajes')
        .where('cliente_id', isEqualTo: clienteId)
        .where('estado', whereIn: ['aceptado', 'en curso'])
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final conductorPos = data['ubicacion_conductor'];
        final estado = data['estado'];
        final destinoLat = data['destino_lat'];
        final destinoLng = data['destino_lng'];

        if (estado == 'aceptado' && conductorPos != null) {
          final geo = conductorPos as GeoPoint;
          final LatLng pos = LatLng(geo.latitude, geo.longitude);

          if (conductorSymbol != null) mapController?.removeSymbol(conductorSymbol!);
          conductorSymbol = await mapController?.addSymbol(SymbolOptions(
            geometry: pos,
            iconImage: "marker-15",
            iconSize: 1.5,
          ));

          final distancia = Geolocator.distanceBetween(
            ubicacionActual!.latitude, ubicacionActual!.longitude,
            pos.latitude, pos.longitude,
          );
          if (distancia < 50 && !modalMostrado) {
            modalMostrado = true;
            _mostrarModalLlegada();
          }
        }

        if (estado == 'en curso' && destinoLat != null && destinoLng != null) {
          final destino = LatLng(destinoLat, destinoLng);
          mapController?.clearSymbols();
          mapController?.clearLines();

          final ruta = await OpenRouteServiceAPI.obtenerRuta(
            origen: ubicacionActual!,
            destino: destino,
          );

          await mapController?.addSymbol(SymbolOptions(
            geometry: destino,
            iconImage: "marker-15",
            iconSize: 1.5,
          ));

          await mapController?.addLine(LineOptions(
            geometry: ruta,
            lineColor: "#00C851",
            lineWidth: 5,
          ));
        }
      }
    });
  }

  void _mostrarModalLlegada() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🚗 ¡Ha llegado tu transporte!"),
        content: const Text("Tu conductor está cerca, por favor prepárate."),
        actions: [
          TextButton(
            child: const Text("Aceptar"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _onMapTap(Point<double> point, LatLng coordinates) async {
    if (destinoSymbol != null) {
      mapController!.removeSymbol(destinoSymbol!);
    }

    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordinates,
      iconImage: "marker-15",
      iconSize: 1.5,
    ));

    setState(() {
      destinoSeleccionado = coordinates;
    });

    await _trazarRutaReal();
  }

  Future<void> _trazarRutaReal() async {
    if (ubicacionActual == null || destinoSeleccionado == null) return;

    if (rutaLine != null) {
      mapController!.removeLine(rutaLine!);
    }

    final puntosRuta = await OpenRouteServiceAPI.obtenerRuta(
      origen: ubicacionActual!,
      destino: destinoSeleccionado!,
    );

    if (puntosRuta.isNotEmpty) {
      rutaLine = await mapController!.addLine(LineOptions(
        geometry: puntosRuta,
        lineColor: "#007AFF",
        lineWidth: 5,
      ));
    }
  }

  Future<void> _buscarSugerencias(String texto) async {
    if (ubicacionActual == null || texto.trim().isEmpty) {
      setState(() {
        sugerencias.clear();
      });
      return;
    }

    final resultados = await OpenRouteServiceAPI.autocompletarBusqueda(texto, ubicacionActual!);
    setState(() {
      sugerencias = resultados;
    });
  }

  void _seleccionarSugerencia(LatLng coordenadas) async {
    _searchController.clear();
    setState(() {
      sugerencias.clear();
    });

    if (destinoSymbol != null) {
      mapController!.removeSymbol(destinoSymbol!);
    }

    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordenadas,
      iconImage: "marker-15",
      iconSize: 1.5,
    ));

    destinoSeleccionado = coordenadas;
    await _trazarRutaReal();
    mapController!.animateCamera(CameraUpdate.newLatLngZoom(coordenadas, 15));
  }

  void _mostrarEstimacion(double distancia, double tarifa) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🚕 Estimación del Viaje",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Distancia: ${distancia.toStringAsFixed(2)} km"),
              const SizedBox(height: 5),
              Text("Costo estimado: Bs. ${tarifa.toStringAsFixed(2)}"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (ubicacionActual != null && destinoSeleccionado != null) {
                    await crearViajeEnFirebase(
                      origen: ubicacionActual!,
                      destino: destinoSeleccionado!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🚗 ¡Viaje solicitado con éxito!')),
                      );
                    }
                    Navigator.pop(context);
                  }
                },
                child: const Text("Confirmar viaje"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ubicacionActual == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "¿A dónde vas?",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.grey[100],
                        filled: true,
                      ),
                      onChanged: _buscarSugerencias,
                    ),
                    if (sugerencias.isNotEmpty)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: sugerencias.length,
                          itemBuilder: (context, index) {
                            final item = sugerencias[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(item['nombre']),
                              onTap: () {
                                _seleccionarSugerencia(item['coordenadas']);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MaplibreMap(
                    styleString: "https://api.maptiler.com/maps/outdoor-v2/style.json?key=Y2TaDOuaHgeijPZP0ZiP",
                    initialCameraPosition: CameraPosition(
                      target: ubicacionActual!,
                      zoom: 14.0,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: true,
                    myLocationTrackingMode: MyLocationTrackingMode.tracking,
                    compassEnabled: true,
                    onMapClick: _onMapTap,
                  ),
                ),
              ),
              if (destinoSeleccionado != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (ubicacionActual != null && destinoSeleccionado != null) {
                        final distanciaKm = calcularDistanciaKm(ubicacionActual!, destinoSeleccionado!);
                        final tarifaEstimado = calcularTarifa(distanciaKm);

                        _mostrarEstimacion(distanciaKm, tarifaEstimado);
                      }
                    },
                    icon: const Icon(Icons.directions_car),
                    label: const Text("Solicitar viaje"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ),
            ],
          );
  }
}
