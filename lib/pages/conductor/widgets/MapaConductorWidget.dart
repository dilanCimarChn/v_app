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
  Symbol? conductorSymbol;
  Symbol? origenSymbol;
  Symbol? destinoSymbol;
  Line? rutaLine;
  Map<String, dynamic>? viajeActivo;
  String? idViaje;
  bool viajeIniciado = false;
  Set<String> viajesMostrados = {};

  // Colores consistentes con el mapa cliente
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

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
    
    try {
      Position posicion = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          ubicacionConductor = LatLng(posicion.latitude, posicion.longitude);
        });
      }
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
    }
  }

  void _onMapCreated(MaplibreMapController controller) async {
    mapController = controller;
    
    // CORRECCIÓN: Esperar un poco para que el mapa se inicialice
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (ubicacionConductor != null && mapController != null) {
      try {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(ubicacionConductor!, 15));
        
        // CORRECCIÓN: Verificar que el controlador sigue disponible
        if (mounted && mapController != null) {
          conductorSymbol = await controller.addSymbol(SymbolOptions(
            geometry: ubicacionConductor!,
            iconImage: "marker-15",
            iconSize: 2.0,
            iconColor: "#2196F3",
            textField: "🚗 Tú (Conductor)",
            textOffset: const Offset(0, 2.8),
            textSize: 12,
            textColor: "#2196F3",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));
        }
      } catch (e) {
        print('❌ Error al crear símbolo en mapa: $e');
      }
    }
  }

  void _escucharViajesPendientes() {
    print('🚗 Conductor: Iniciando listener de viajes pendientes');
    
    _viajeSubscription = FirebaseFirestore.instance
        .collection('viajes')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snapshot) {
      print('🔄 Conductor: Snapshot recibido - ${snapshot.docs.length} viajes pendientes');
      
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final viajeId = doc.id;
          final data = doc.data() as Map<String, dynamic>;
          
          print('📋 Conductor: Viaje encontrado - ID: $viajeId');
          print('📊 Conductor: Datos del viaje: $data'); // DEBUG: Ver todos los datos
          
          // CORRECCIÓN MEJORADA: Validar coordenadas más estrictamente
          if (_validarCoordenadasViaje(data)) {
            if (!viajesMostrados.contains(viajeId) && viajeActivo == null) {
              print('✅ Conductor: Mostrando modal para viaje $viajeId');
              viajesMostrados.add(viajeId);
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && viajeActivo == null) {
                  _mostrarModalAceptacion(doc);
                }
              });
              
              break;
            } else {
              print('⚠️ Conductor: Viaje $viajeId ya mostrado o conductor ocupado');
            }
          } else {
            print('❌ Conductor: Viaje $viajeId tiene coordenadas inválidas - saltando');
            // NUEVO: Marcar como mostrado para evitar intentos repetidos
            viajesMostrados.add(viajeId);
          }
        }
      } else {
        print('📭 Conductor: No hay viajes pendientes');
      }
    }, onError: (error) {
      print('❌ Conductor: Error en listener: $error');
    });
  }

  // NUEVA FUNCIÓN: Validar coordenadas del viaje
  bool _validarCoordenadasViaje(Map<String, dynamic> data) {
    // Verificar que existan todas las coordenadas necesarias
    final origenLat = data['origen_lat'];
    final origenLng = data['origen_lng'];
    final destinoLat = data['destino_lat'];
    final destinoLng = data['destino_lng'];
    
    print('🔍 Conductor: Validando coordenadas:');
    print('   origen_lat: $origenLat (${origenLat.runtimeType})');
    print('   origen_lng: $origenLng (${origenLng.runtimeType})');
    print('   destino_lat: $destinoLat (${destinoLat.runtimeType})');
    print('   destino_lng: $destinoLng (${destinoLng.runtimeType})');
    
    if (origenLat == null || origenLng == null || destinoLat == null || destinoLng == null) {
      print('❌ Conductor: Coordenadas faltantes');
      return false;
    }
    
    // Verificar que sean números válidos
    try {
      final double oLat = origenLat.toDouble();
      final double oLng = origenLng.toDouble();
      final double dLat = destinoLat.toDouble();
      final double dLng = destinoLng.toDouble();
      
      // Verificar rangos válidos de coordenadas
      if (oLat < -90 || oLat > 90 || dLat < -90 || dLat > 90) {
        print('❌ Conductor: Latitudes fuera de rango válido');
        return false;
      }
      
      if (oLng < -180 || oLng > 180 || dLng < -180 || dLng > 180) {
        print('❌ Conductor: Longitudes fuera de rango válido');
        return false;
      }
      
      print('✅ Conductor: Coordenadas válidas');
      return true;
    } catch (e) {
      print('❌ Conductor: Error al convertir coordenadas: $e');
      return false;
    }
  }

  void _mostrarModalAceptacion(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    
    // Ya sabemos que las coordenadas son válidas por la validación previa
    final origen = LatLng(data['origen_lat'].toDouble(), data['origen_lng'].toDouble());
    final destino = LatLng(data['destino_lat'].toDouble(), data['destino_lng'].toDouble());

    // CORRECCIÓN: Validación segura de números con valores por defecto
    double distancia = 0.0;
    double tarifa = 0.0;
    
    final rawDistancia = data['distancia_km'];
    final rawTarifa = data['tarifa'];
    
    if (rawDistancia != null) {
      try {
        distancia = rawDistancia.toDouble();
      } catch (e) {
        print('⚠️ Conductor: Error al convertir distancia: $e');
        // Calcular distancia manualmente si falla
        distancia = _calcularDistanciaSimple(origen, destino);
      }
    } else {
      // Calcular distancia si no existe
      distancia = _calcularDistanciaSimple(origen, destino);
    }
    
    if (rawTarifa != null) {
      try {
        tarifa = rawTarifa.toDouble();
      } catch (e) {
        print('⚠️ Conductor: Error al convertir tarifa: $e');
        // Calcular tarifa manualmente si falla
        tarifa = _calcularTarifaSimple(distancia);
      }
    } else {
      // Calcular tarifa si no existe
      tarifa = _calcularTarifaSimple(distancia);
    }

    final user = FirebaseAuth.instance.currentUser;
    final conductorId = user?.uid;
    String conductorNombre = 'Conductor';

    if (user != null) {
      try {
        final conductorQuery = await FirebaseFirestore.instance
            .collection('usuario-app')
            .where('email', isEqualTo: user.email)
            .where('rol', isEqualTo: 'conductor')
            .get();

        if (conductorQuery.docs.isNotEmpty) {
          conductorNombre = conductorQuery.docs.first.data()['name'] ?? 'Conductor';
        }
      } catch (e) {
        print('⚠️ Error al obtener nombre del conductor: $e');
      }
    }

    final clienteId = data['cliente_id'];
    String clienteNombre = 'Cliente';

    if (clienteId != null) {
      try {
        final clienteDoc = await FirebaseFirestore.instance
            .collection('usuario-app')
            .doc(clienteId)
            .get();
        
        if (clienteDoc.exists) {
          clienteNombre = clienteDoc.data()?['name'] ?? 'Cliente';
        }
      } catch (e) {
        print('⚠️ Error al obtener nombre del cliente: $e');
      }
    }

    // CORRECCIÓN: Verificar que el widget sigue montado antes de mostrar el modal
    if (!mounted) return;

    print('🎯 Conductor: Mostrando modal con datos:');
    print('   Cliente: $clienteNombre');
    print('   Conductor: $conductorNombre');
    print('   Distancia: ${distancia.toStringAsFixed(2)} km');
    print('   Tarifa: Bs. ${tarifa.toStringAsFixed(2)}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.local_taxi, color: warningColor, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Nuevo viaje disponible",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.person, "Cliente", clienteNombre, primaryColor),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.drive_eta, "Conductor", conductorNombre, successColor),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.straighten, "Distancia", "${distancia.toStringAsFixed(2)} km", warningColor),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.attach_money, "Tarifa", "Bs. ${tarifa.toStringAsFixed(2)}", successColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viajesMostrados.remove(doc.id);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Rechazar", style: TextStyle(color: errorColor, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                print('📝 Conductor: Actualizando viaje en Firestore');
                await FirebaseFirestore.instance.collection('viajes').doc(doc.id).update({
                  'estado': 'aceptado',
                  'conductor_id': conductorId,
                  'conductor_nombre': conductorNombre,
                  'cliente_nombre': clienteNombre,
                  'distancia_km': distancia,
                  'tarifa': tarifa,
                  'fecha_aceptacion': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
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
                }
              } catch (e) {
                print('❌ Error al aceptar viaje: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al aceptar viaje: $e'),
                      backgroundColor: errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Aceptar viaje", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  // NUEVAS FUNCIONES: Cálculos de respaldo
  double _calcularDistanciaSimple(LatLng origen, LatLng destino) {
    try {
      final distanciaMetros = Geolocator.distanceBetween(
        origen.latitude, origen.longitude,
        destino.latitude, destino.longitude,
      );
      return distanciaMetros / 1000; // Convertir a kilómetros
    } catch (e) {
      print('❌ Error al calcular distancia: $e');
      return 5.0; // Valor por defecto
    }
  }

  double _calcularTarifaSimple(double distanciaKm) {
    const double precioBase = 5.0;
    const double precioPorKm = 3.5;
    return precioBase + (distanciaKm * precioPorKm);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarRutaAlCliente(LatLng clienteOrigen) async {
    if (ubicacionConductor == null || mapController == null) return;

    print('🗺️ Conductor: Trazando ruta al cliente');

    try {
      List<LatLng> puntos = [];
      
      try {
        puntos = await OpenRouteServiceAPI.obtenerRuta(
          origen: ubicacionConductor!,
          destino: clienteOrigen,
        );
        print('✅ Conductor: Ruta obtenida de OpenRouteService');
      } catch (e) {
        print('⚠️ Conductor: OpenRouteService falló, usando línea directa: $e');
        puntos = [ubicacionConductor!, clienteOrigen];
      }

      if (mapController != null) {
        await mapController!.clearLines();
        await mapController!.clearSymbols();
        
        // Agregar conductor (yo) con icono azul
        conductorSymbol = await mapController!.addSymbol(SymbolOptions(
          geometry: ubicacionConductor!,
          iconImage: "marker-15",
          iconSize: 2.0,
          iconColor: "#2196F3",
          textField: "🚗 Tú (Conductor)",
          textOffset: const Offset(0, 2.8),
          textSize: 12,
          textColor: "#2196F3",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
        ));
        
        // Agregar cliente con icono verde
        origenSymbol = await mapController!.addSymbol(SymbolOptions(
          geometry: clienteOrigen,
          iconImage: "marker-15",
          iconSize: 1.8,
          iconColor: "#4CAF50",
          textField: "🏠 Cliente (Origen)",
          textOffset: const Offset(0, 2.5),
          textSize: 12,
          textColor: "#4CAF50",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
        ));

        // Ruta hacia el cliente con color distintivo
        if (puntos.isNotEmpty) {
          rutaLine = await mapController!.addLine(LineOptions(
            geometry: puntos,
            lineColor: "#FF9800",
            lineWidth: 6,
            lineOpacity: 0.8,
          ));
        }
        
        // Centrar el mapa para mostrar ambos puntos
        final bounds = _calcularBounds([ubicacionConductor!, clienteOrigen]);
        await mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds));
      }
    } catch (e) {
      print('❌ Error al mostrar ruta al cliente: $e');
    }
  }

  LatLngBounds _calcularBounds(List<LatLng> puntos) {
    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (LatLng punto in puntos) {
      minLat = minLat < punto.latitude ? minLat : punto.latitude;
      maxLat = maxLat > punto.latitude ? maxLat : punto.latitude;
      minLng = minLng < punto.longitude ? minLng : punto.longitude;
      maxLng = maxLng > punto.longitude ? maxLng : punto.longitude;
    }

    const padding = 0.001;
    
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Future<void> _iniciarViaje() async {
    if (viajeActivo == null || idViaje == null) return;

    print('🚀 Conductor: Iniciando viaje');

    try {
      final destino = LatLng(viajeActivo!['destino_lat'], viajeActivo!['destino_lng']);
      final origen = LatLng(viajeActivo!['origen_lat'], viajeActivo!['origen_lng']);
      
      List<LatLng> puntos = [];
      
      try {
        puntos = await OpenRouteServiceAPI.obtenerRuta(
          origen: origen,
          destino: destino,
        );
        print('✅ Conductor: Ruta del viaje obtenida');
      } catch (e) {
        print('⚠️ Conductor: Error en ruta, usando línea directa: $e');
        puntos = [origen, destino];
      }

      if (mapController != null) {
        await mapController!.clearLines();
        await mapController!.clearSymbols();
        
        // Origen del cliente
        origenSymbol = await mapController!.addSymbol(SymbolOptions(
          geometry: origen,
          iconImage: "marker-15",
          iconSize: 1.8,
          iconColor: "#4CAF50",
          textField: "🏠 Origen",
          textOffset: const Offset(0, 2.5),
          textSize: 12,
          textColor: "#4CAF50",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
        ));
        
        // Destino del viaje
        destinoSymbol = await mapController!.addSymbol(SymbolOptions(
          geometry: destino,
          iconImage: "marker-15",
          iconSize: 1.8,
          iconColor: "#F44336",
          textField: "🎯 Destino",
          textOffset: const Offset(0, 2.5),
          textSize: 12,
          textColor: "#F44336",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
        ));

        // Ruta del viaje
        if (puntos.isNotEmpty) {
          await mapController!.addLine(LineOptions(
            geometry: puntos,
            lineColor: "#4CAF50",
            lineWidth: 6,
            lineOpacity: 0.8,
          ));
        }
      }

      await FirebaseFirestore.instance.collection('viajes').doc(idViaje!).update({
        'estado': 'en_curso',
        'fecha_inicio': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          viajeIniciado = true;
        });
      }
      
      print('✅ Conductor: Viaje iniciado correctamente');
    } catch (e) {
      print('❌ Error al iniciar viaje: $e');
    }
  }

  Future<void> _finalizarViaje() async {
    if (idViaje == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final viajeRef = FirebaseFirestore.instance.collection('viajes').doc(idViaje!);
      
      batch.update(viajeRef, {
        'estado': 'finalizado',
        'fecha_finalizacion': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();

      if (mounted) {
        setState(() {
          viajeActivo = null;
          idViaje = null;
          viajeIniciado = false;
        });
      }

      mapController?.clearLines();
      mapController?.clearSymbols();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('¡Viaje finalizado con éxito!'),
              ],
            ),
            backgroundColor: successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al finalizar viaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar viaje: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _cancelarViaje() async {
    if (idViaje == null) return;

    try {
      await FirebaseFirestore.instance.collection('viajes').doc(idViaje!).update({
        'estado': 'cancelado',
        'fecha_cancelacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          viajeActivo = null;
          idViaje = null;
          viajeIniciado = false;
        });
      }

      mapController?.clearLines();
      mapController?.clearSymbols();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 10),
                Text('Viaje cancelado'),
              ],
            ),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al cancelar viaje: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ubicacionConductor == null
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
        : Stack(
            children: [
              // Mapa con esquinas redondeadas
              Container(
                margin: const EdgeInsets.all(16),
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
                      target: ubicacionConductor!,
                      zoom: 14.0,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: true,
                    myLocationTrackingMode: MyLocationTrackingMode.tracking,
                  ),
                ),
              ),
              
              // Información del viaje mejorada
              if (viajeActivo != null)
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.info, color: primaryColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Información del Viaje",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Información detallada
                        _buildInfoRow(Icons.person, "Cliente", viajeActivo!['cliente_nombre'] ?? 'Cliente', primaryColor),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.drive_eta, "Conductor", viajeActivo!['conductor_nombre'] ?? 'Conductor', successColor),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.straighten, "Distancia", "${viajeActivo!['distancia_km']?.toStringAsFixed(2) ?? '0.00'} km", warningColor),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.attach_money, "Tarifa", "Bs. ${viajeActivo!['tarifa']?.toStringAsFixed(2) ?? '0.00'}", successColor),
                      ],
                    ),
                  ),
                ),
              
              // Botones de acción mejorados
              if (viajeActivo != null)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón finalizar viaje (solo cuando el viaje está iniciado)
                      if (viajeIniciado) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _finalizarViaje,
                            icon: const Icon(Icons.flag, color: Colors.white, size: 24),
                            label: const Text(
                              "Finalizar viaje",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: successColor,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                      
                      // Botón iniciar/cancelar viaje
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: viajeIniciado ? _cancelarViaje : _iniciarViaje,
                          icon: Icon(
                            viajeIniciado ? Icons.cancel : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                          label: Text(
                            viajeIniciado ? "Cancelar viaje" : "Iniciar viaje",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: viajeIniciado ? errorColor : primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
  }
}