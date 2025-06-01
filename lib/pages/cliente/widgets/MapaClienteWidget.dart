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
  Symbol? origenSymbol;
  Symbol? destinoSymbol;
  Line? rutaLine;
  Symbol? conductorSymbol;
  Line? rutaAlDestino;
  StreamSubscription? viajeListener;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> sugerencias = [];
  bool modalMostrado = false;

  // Colores mejorados
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

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

  void _onMapCreated(MaplibreMapController controller) async {
    mapController = controller;

    if (ubicacionActual != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(ubicacionActual!, 15),
      );
      
      // Agregar marcador de origen con estilo verde y emoji
      origenSymbol = await controller.addSymbol(SymbolOptions(
        geometry: ubicacionActual!,
        iconImage: "marker-15",
        iconSize: 1.8,
        iconColor: "#4CAF50", // Verde para origen
        textField: "Tu ubicación",
        textOffset: const Offset(0, 2.5),
        textSize: 12,
        textColor: "#4CAF50",
        textHaloColor: "#FFFFFF",
        textHaloWidth: 1.5,
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

          // Remover conductor anterior si existe
          if (conductorSymbol != null) mapController?.removeSymbol(conductorSymbol!);
          
          // Agregar conductor con icono de auto azul
          conductorSymbol = await mapController?.addSymbol(SymbolOptions(
            geometry: pos,
            iconImage: "marker-15",
            iconSize: 2.0,
            iconColor: "#2196F3", // Azul para conductor
            textField: "🚕 Tu conductor",
            textOffset: const Offset(0, 2.8),
            textSize: 11,
            textColor: "#2196F3",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
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

          // Agregar origen con estilo verde
          origenSymbol = await mapController?.addSymbol(SymbolOptions(
            geometry: ubicacionActual!,
            iconImage: "marker-15",
            iconSize: 1.8,
            iconColor: "#4CAF50",
            textField: "🔷 Origen",
            textOffset: const Offset(0, 2.5),
            textSize: 12,
            textColor: "#4CAF50",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));

          // Agregar destino con estilo rojo
          await mapController?.addSymbol(SymbolOptions(
            geometry: destino,
            iconImage: "marker-15",
            iconSize: 1.8,
            iconColor: "#F44336",
            textField: "📍 Destino",
            textOffset: const Offset(0, 2.5),
            textSize: 12,
            textColor: "#F44336",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));

          // Agregar ruta con mejor estilo
          await mapController?.addLine(LineOptions(
            geometry: ruta,
            lineColor: "#4CAF50",
            lineWidth: 6,
            lineOpacity: 0.8,
          ));
        }
      }
    });
  }

  void _mostrarModalLlegada() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.directions_car, color: successColor, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "¡Ha llegado tu transporte!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          "Tu conductor está cerca, por favor prepárate para abordar.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Entendido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapTap(Point<double> point, LatLng coordinates) async {
    if (destinoSymbol != null) {
      mapController!.removeSymbol(destinoSymbol!);
    }

    // Agregar destino con icono rojo y emoji
    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordinates,
      iconImage: "marker-15",
      iconSize: 1.8,
      iconColor: "#F44336", // Rojo para destino
      textField: "📍 Destino",
      textOffset: const Offset(0, 2.5),
      textSize: 12,
      textColor: "#F44336",
      textHaloColor: "#FFFFFF",
      textHaloWidth: 1.5,
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
        lineColor: "#2196F3",
        lineWidth: 6,
        lineOpacity: 0.8,
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

    // Agregar destino seleccionado con icono rojo
    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordenadas,
      iconImage: "marker-15",
      iconSize: 1.8,
      iconColor: "#F44336",
      textField: "🔷 Destino",
      textOffset: const Offset(0, 2.5),
      textSize: 12,
      textColor: "#F44336",
      textHaloColor: "#FFFFFF",
      textHaloWidth: 1.5,
    ));

    destinoSeleccionado = coordenadas;
    await _trazarRutaReal();
    mapController!.animateCamera(CameraUpdate.newLatLngZoom(coordenadas, 15));
  }

  void _mostrarEstimacion(double distancia, double tarifa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              
              // Título con icono mejorado
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.directions_car, color: primaryColor, size: 32),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "Estimación del Viaje",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              
              const SizedBox(height: 25),
              
              // Información del viaje mejorada
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.straighten, "Distancia", "${distancia.toStringAsFixed(2)} km", primaryColor),
                    const SizedBox(height: 15),
                    _buildInfoRow(Icons.attach_money, "Costo estimado", "Bs. ${tarifa.toStringAsFixed(2)}", successColor),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              
              // Botón mejorado
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (ubicacionActual != null && destinoSeleccionado != null) {
                      await crearViajeEnFirebase(
                        origen: ubicacionActual!,
                        destino: destinoSeleccionado!,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 10),
                                Text('¡Viaje solicitado con éxito!'),
                              ],
                            ),
                            backgroundColor: successColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Confirmar viaje",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ubicacionActual == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  "Obteniendo tu ubicación...",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Barra de búsqueda mejorada
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "¿A dónde quieres ir?",
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onChanged: _buscarSugerencias,
                    ),
                    
                    // Lista de sugerencias mejorada
                    if (sugerencias.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sugerencias.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final item = sugerencias[index];
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.location_on, color: primaryColor, size: 20),
                              ),
                              title: Text(
                                item['nombre'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
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
              
              // Mapa con mejor estilo
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
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
              ),
              
              // Botón solicitar viaje mejorado
              if (destinoSeleccionado != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (ubicacionActual != null && destinoSeleccionado != null) {
                          final distanciaKm = calcularDistanciaKm(ubicacionActual!, destinoSeleccionado!);
                          final tarifaEstimado = calcularTarifa(distanciaKm);
                          _mostrarEstimacion(distanciaKm, tarifaEstimado);
                        }
                      },
                      icon: const Icon(Icons.directions_car, color: Colors.white),
                      label: const Text(
                        "Solicitar viaje",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ),
            ],
          );
  }
}