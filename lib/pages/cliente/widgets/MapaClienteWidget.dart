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
import 'package:v_app/services/membresia_service.dart';

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
  
  // NUEVA LÍNEA PARA RUTA DEL CONDUCTOR
  Line? rutaConductor;
  
  StreamSubscription? viajeListener;
  
  // NUEVO TIMER PARA ACTUALIZACIÓN DE UBICACIÓN DEL CONDUCTOR
  Timer? actualizacionConductorTimer;
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> sugerencias = [];
  bool modalMostrado = false;
  bool modalCalificacionMostrado = false;
  
  // NUEVAS VARIABLES PARA CONTROLAR ESTADO DE CALIFICACIÓN
  String? viajeActivoId;
  bool yaCalificado = false;

  // NUEVAS VARIABLES PARA PREMIUM
  bool tienePlanPremium = false;
  int viajesRestantes = 0;
  double descuentoPorcentaje = 15.0;

  // Colores mejorados
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color premiumColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
    _escucharViajeAsignado();
    _verificarPlanPremium();
  }

  @override
  void dispose() {
    viajeListener?.cancel();
    actualizacionConductorTimer?.cancel(); // NUEVO: Cancelar timer
    super.dispose();
  }

  // FUNCIÓN EXISTENTE SIN CAMBIOS
  Future<void> _verificarPlanPremium() async {
    final planInfo = await MembresiaService.verificarPlanPremium();
    if (mounted) {
      setState(() {
        tienePlanPremium = planInfo['activo'] ?? false;
        viajesRestantes = planInfo['viajes_restantes'] ?? 0;
      });
    }
  }

  // FUNCIÓN EXISTENTE SIN CAMBIOS
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

  // FUNCIÓN EXISTENTE SIN CAMBIOS
  void _onMapCreated(MaplibreMapController controller) async {
    mapController = controller;

    if (ubicacionActual != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(ubicacionActual!, 15),
      );
      
      origenSymbol = await controller.addSymbol(SymbolOptions(
        geometry: ubicacionActual!,
        iconImage: "marker-15",
        iconSize: 1.8,
        iconColor: "#4CAF50",
        textField: "Tu ubicación",
        textOffset: const Offset(0, 2.5),
        textSize: 12,
        textColor: "#4CAF50",
        textHaloColor: "#FFFFFF",
        textHaloWidth: 1.5,
      ));
    }
  }

  // FUNCIÓN MODIFICADA: Listener principal con correcciones
  void _escucharViajeAsignado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clienteId = user.uid;

    viajeListener = FirebaseFirestore.instance
        .collection('viajes')
        .where('cliente_id', isEqualTo: clienteId)
        .where('estado', whereIn: ['aceptado', 'en_curso', 'finalizado'])
        .snapshots()
        .listen((snapshot) async {
      print('🔄 Cliente: Cambio en viajes detectado - ${snapshot.docs.length} documentos');
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final conductorPos = data['ubicacion_conductor'];
        final estado = data['estado'];
        final destinoLat = data['destino_lat'];
        final destinoLng = data['destino_lng'];
        
        print('📍 Cliente: Estado del viaje: $estado');
        
        // ACTUALIZAR ID DEL VIAJE ACTIVO
        viajeActivoId = doc.id;

        if (estado == 'aceptado' && conductorPos != null) {
          print('✅ Cliente: Viaje aceptado, mostrando conductor y ruta');
          final geo = conductorPos as GeoPoint;
          final LatLng posConductor = LatLng(geo.latitude, geo.longitude);

          // NUEVA FUNCIONALIDAD: Mostrar conductor con ruta hacia cliente
          await _mostrarConductorConRuta(posConductor);
          
          // INICIAR ACTUALIZACIÓN PERIÓDICA DE LA UBICACIÓN DEL CONDUCTOR
          _iniciarActualizacionConductor();

          final distancia = Geolocator.distanceBetween(
            ubicacionActual!.latitude, ubicacionActual!.longitude,
            posConductor.latitude, posConductor.longitude,
          );
          if (distancia < 50 && !modalMostrado) {
            modalMostrado = true;
            _mostrarModalLlegada();
          }
        }

        if (estado == 'en_curso' && destinoLat != null && destinoLng != null) {
          print('🚗 Cliente: Viaje en curso, mostrando ruta del viaje');
          
          // DETENER ACTUALIZACIÓN DEL CONDUCTOR
          actualizacionConductorTimer?.cancel();
          
          final destino = LatLng(destinoLat, destinoLng);
          mapController?.clearSymbols();
          mapController?.clearLines();

          final ruta = await _obtenerRutaSegura(ubicacionActual!, destino);

          // Agregar marcadores del viaje
          origenSymbol = await mapController?.addSymbol(SymbolOptions(
            geometry: ubicacionActual!,
            iconImage: "marker-15",
            iconSize: 1.8,
            iconColor: "#4CAF50",
            textField: "Origen",
            textOffset: const Offset(0, 2.5),
            textSize: 12,
            textColor: "#4CAF50",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));

          await mapController?.addSymbol(SymbolOptions(
            geometry: destino,
            iconImage: "marker-15",
            iconSize: 1.8,
            iconColor: "#F44336",
            textField: "Destino",
            textOffset: const Offset(0, 2.5),
            textSize: 12,
            textColor: "#F44336",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));

          await mapController?.addLine(LineOptions(
            geometry: ruta,
            lineColor: "#4CAF50",
            lineWidth: 6,
            lineOpacity: 0.8,
          ));
        }

        // CORRECCIÓN MEJORADA DEL MODAL DE CALIFICACIÓN
        if (estado == 'finalizado') {
          print('🏁 Cliente: Viaje finalizado detectado');
          
          // DETENER CUALQUIER ACTUALIZACIÓN EN CURSO
          actualizacionConductorTimer?.cancel();
          
          // VERIFICAR CALIFICACIÓN DE MANERA MÁS ROBUSTA
          final calificacionGeneral = data['calificacion_general'];
          yaCalificado = calificacionGeneral != null && calificacionGeneral > 0;
          
          print('⭐ Cliente: Calificación actual: $calificacionGeneral');
          print('⭐ Cliente: Ya calificado: $yaCalificado');
          print('⭐ Cliente: Modal mostrado: $modalCalificacionMostrado');
          
          // CONDICIÓN MEJORADA PARA MOSTRAR MODAL
          if (!yaCalificado && !modalCalificacionMostrado) {
            print('📱 Cliente: Preparando modal de calificación');
            modalCalificacionMostrado = true;
            
            // DELAY MÁS LARGO PARA ASEGURAR ESTABILIDAD
            await Future.delayed(const Duration(milliseconds: 1000));
            
            if (mounted && !yaCalificado) {
              // VERIFICAR NUEVAMENTE ANTES DE MOSTRAR
              final docActualizado = await FirebaseFirestore.instance
                  .collection('viajes')
                  .doc(doc.id)
                  .get();
              
              if (docActualizado.exists) {
                final dataActualizada = docActualizado.data()!;
                final calificacionActual = dataActualizada['calificacion_general'];
                
                if (calificacionActual == null || calificacionActual == 0) {
                  print('📱 Cliente: Mostrando modal de calificación (verificación doble)');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !yaCalificado) {
                      _mostrarModalCalificacion(doc.id, data['conductor_nombre'] ?? 'Conductor');
                    }
                  });
                } else {
                  print('⭐ Cliente: Viaje ya fue calificado en verificación doble');
                  yaCalificado = true;
                }
              }
            }
          }
        }
        
        // LIMPIAR MAPA SI EL VIAJE YA FUE CALIFICADO
        if (estado == 'finalizado' && yaCalificado) {
          print('🧹 Cliente: Limpiando mapa - viaje ya calificado');
          await Future.delayed(const Duration(seconds: 2));
          _limpiarMapa();
        }
      } else {
        print('❌ Cliente: No hay viajes activos, reseteando estado');
        // RESETEAR TODOS LOS FLAGS Y TIMERS
        if (mounted) {
          setState(() {
            modalMostrado = false;
            modalCalificacionMostrado = false;
            viajeActivoId = null;
            yaCalificado = false;
          });
        }
        actualizacionConductorTimer?.cancel();
        _limpiarMapa();
      }
    }, onError: (error) {
      print('❌ Cliente: Error en listener de viajes: $error');
    });
  }

  // NUEVA FUNCIÓN: Mostrar conductor con ruta hacia cliente
  Future<void> _mostrarConductorConRuta(LatLng posConductor) async {
    if (mapController == null || ubicacionActual == null) return;

    try {
      // Limpiar conductor y ruta anterior
      if (conductorSymbol != null) {
        await mapController!.removeSymbol(conductorSymbol!);
      }
      if (rutaConductor != null) {
        await mapController!.removeLine(rutaConductor!);
      }

      // Agregar nuevo marcador del conductor
      conductorSymbol = await mapController!.addSymbol(SymbolOptions(
        geometry: posConductor,
        iconImage: "marker-15",
        iconSize: 2.0,
        iconColor: "#2196F3",
        textField: "🚗 Tu conductor",
        textOffset: const Offset(0, 2.8),
        textSize: 11,
        textColor: "#2196F3",
        textHaloColor: "#FFFFFF",
        textHaloWidth: 1.5,
      ));

      // NUEVA FUNCIONALIDAD: Trazar ruta del conductor hacia el cliente
      print('🗺️ Cliente: Trazando ruta del conductor hacia ti');
      
      final rutaPuntos = await _obtenerRutaSegura(posConductor, ubicacionActual!);
      
      if (rutaPuntos.isNotEmpty) {
        rutaConductor = await mapController!.addLine(LineOptions(
          geometry: rutaPuntos,
          lineColor: "#FF9800", // Naranja para ruta del conductor
          lineWidth: 5,
          lineOpacity: 0.8,
        ));
        
        print('✅ Cliente: Ruta del conductor agregada al mapa');
      }

      // Ajustar vista del mapa para mostrar ambos puntos
      final bounds = _calcularBounds([posConductor, ubicacionActual!]);
      await mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds));
      
    } catch (e) {
      print('❌ Cliente: Error al mostrar conductor con ruta: $e');
    }
  }

  // NUEVA FUNCIÓN: Iniciar actualización periódica del conductor
  void _iniciarActualizacionConductor() {
    // Cancelar timer anterior si existe
    actualizacionConductorTimer?.cancel();
    
    // Crear nuevo timer que se ejecuta cada 10 segundos
    actualizacionConductorTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (viajeActivoId != null && mounted) {
        try {
          print('🔄 Cliente: Actualizando ubicación del conductor...');
          
          final viajeDoc = await FirebaseFirestore.instance
              .collection('viajes')
              .doc(viajeActivoId!)
              .get();
          
          if (viajeDoc.exists) {
            final data = viajeDoc.data()!;
            final estado = data['estado'];
            final conductorPos = data['ubicacion_conductor'];
            
            // Solo actualizar si el viaje sigue aceptado y hay nueva ubicación
            if (estado == 'aceptado' && conductorPos != null) {
              final geo = conductorPos as GeoPoint;
              final nuevaPos = LatLng(geo.latitude, geo.longitude);
              
              await _mostrarConductorConRuta(nuevaPos);
              print('✅ Cliente: Ubicación del conductor actualizada');
            } else {
              // Si el estado cambió, detener actualizaciones
              print('🛑 Cliente: Estado cambió, deteniendo actualizaciones del conductor');
              timer.cancel();
            }
          }
        } catch (e) {
          print('❌ Cliente: Error al actualizar conductor: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  // NUEVA FUNCIÓN: Obtener ruta de manera segura con fallback
  Future<List<LatLng>> _obtenerRutaSegura(LatLng origen, LatLng destino) async {
    try {
      final ruta = await OpenRouteServiceAPI.obtenerRuta(
        origen: origen,
        destino: destino,
      );
      print('✅ Cliente: Ruta obtenida de OpenRouteService');
      return ruta;
    } catch (e) {
      print('⚠️ Cliente: OpenRouteService falló, usando línea directa: $e');
      return [origen, destino];
    }
  }

  // NUEVA FUNCIÓN: Calcular bounds para mostrar múltiples puntos
  LatLngBounds _calcularBounds(List<LatLng> puntos) {
    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (LatLng punto in puntos) {
      if (punto.latitude < minLat) minLat = punto.latitude;
      if (punto.latitude > maxLat) maxLat = punto.latitude;
      if (punto.longitude < minLng) minLng = punto.longitude;
      if (punto.longitude > maxLng) maxLng = punto.longitude;
    }

    const padding = 0.005; // Padding más grande para mejor visualización
    
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  // NUEVA FUNCIÓN: Limpiar mapa de manera segura
  Future<void> _limpiarMapa() async {
    if (mapController != null) {
      try {
        await mapController!.clearSymbols();
        await mapController!.clearLines();
        
        // Restablecer marcador de ubicación actual
        if (ubicacionActual != null) {
          origenSymbol = await mapController!.addSymbol(SymbolOptions(
            geometry: ubicacionActual!,
            iconImage: "marker-15",
            iconSize: 1.8,
            iconColor: "#4CAF50",
            textField: "Tu ubicación",
            textOffset: const Offset(0, 2.5),
            textSize: 12,
            textColor: "#4CAF50",
            textHaloColor: "#FFFFFF",
            textHaloWidth: 1.5,
          ));
        }
        print('🧹 Cliente: Mapa limpiado y restablecido');
      } catch (e) {
        print('❌ Cliente: Error al limpiar mapa: $e');
      }
    }
  }

  // FUNCIÓN EXISTENTE SIN CAMBIOS
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

  // FUNCIÓN CORREGIDA: Modal de calificación con mejor control
  void _mostrarModalCalificacion(String viajeId, String conductorNombre) {
    int calificacion = 0;
    int puntualidad = 0;
    String comentario = '';

    print('📱 Cliente: Abriendo modal de calificación para viaje $viajeId');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.star, color: warningColor, size: 32),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Califica tu viaje",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Conductor: $conductorNombre",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Calificación general:",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          calificacion = index + 1;
                        });
                      },
                      child: Icon(
                        index < calificacion ? Icons.star : Icons.star_border,
                        color: warningColor,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Puntualidad:",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          puntualidad = index + 1;
                        });
                      },
                      child: Icon(
                        index < puntualidad ? Icons.star : Icons.star_border,
                        color: primaryColor,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Comentario (opcional):",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Comparte tu experiencia...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (value) => comentario = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('⏭️ Cliente: Omitiendo calificación');
                Navigator.of(context).pop();
                // MARCAR COMO CALIFICADO PARA EVITAR QUE APAREZCA DE NUEVO
                yaCalificado = true;
              },
              child: Text("Omitir", style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: calificacion > 0 && puntualidad > 0 ? () async {
                print('⭐ Cliente: Enviando calificación - General: $calificacion, Puntualidad: $puntualidad');
                
                try {
                  // ACTUALIZACIÓN ATÓMICA CON BATCH
                  final batch = FirebaseFirestore.instance.batch();
                  final viajeRef = FirebaseFirestore.instance.collection('viajes').doc(viajeId);
                  
                  batch.update(viajeRef, {
                    'calificacion_general': calificacion,
                    'calificacion_puntualidad': puntualidad,
                    'comentario_cliente': comentario,
                    'fecha_calificacion': FieldValue.serverTimestamp(),
                  });
                  
                  await batch.commit();
                  print('✅ Cliente: Calificación guardada exitosamente');

                  // MARCAR COMO CALIFICADO
                  yaCalificado = true;

                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.thumb_up, color: Colors.white),
                          SizedBox(width: 10),
                          Text('¡Gracias por tu calificación!'),
                        ],
                      ),
                      backgroundColor: successColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  
                  // LIMPIAR MAPA DESPUÉS DE CALIFICAR
                  await Future.delayed(const Duration(seconds: 1));
                  _limpiarMapa();
                  
                } catch (e) {
                  print('❌ Cliente: Error al guardar calificación: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar calificación: $e'),
                      backgroundColor: errorColor,
                    ),
                  );
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                "Enviar calificación",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // RESTO DEL CÓDIGO PERMANECE IGUAL (funciones de mapa, búsqueda, etc.)
  Future<void> _onMapTap(Point<double> point, LatLng coordinates) async {
    if (destinoSymbol != null) {
      mapController!.removeSymbol(destinoSymbol!);
    }

    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordinates,
      iconImage: "marker-15",
      iconSize: 1.8,
      iconColor: "#F44336",
      textField: "Destino",
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

    List<LatLng> puntosRuta = await _obtenerRutaSegura(ubicacionActual!, destinoSeleccionado!);

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

    destinoSymbol = await mapController!.addSymbol(SymbolOptions(
      geometry: coordenadas,
      iconImage: "marker-15",
      iconSize: 1.8,
      iconColor: "#F44336",
      textField: "Destino",
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

  // FUNCIÓN MODIFICADA CON DESCUENTOS PREMIUM
  void _mostrarEstimacion(double distancia, double tarifa) {
    // Calcular descuento si tiene plan premium
    double tarifaOriginal = tarifa;
    double descuentoMonto = 0.0;
    double tarifaFinal = tarifa;
    
    if (tienePlanPremium && viajesRestantes > 0) {
      descuentoMonto = tarifa * (descuentoPorcentaje / 100);
      tarifaFinal = tarifa - descuentoMonto;
    }

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
              
              // NUEVA SECCIÓN: Información premium si aplica
              if (tienePlanPremium && viajesRestantes > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "¡Descuento Premium Aplicado!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "Viajes restantes: $viajesRestantes",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "-${descuentoPorcentaje.toInt()}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
              
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
                    
                    // MOSTRAR TARIFA ORIGINAL SI HAY DESCUENTO
                    if (descuentoMonto > 0) ...[
                      _buildInfoRow(Icons.money_off, "Precio original", "Bs. ${tarifaOriginal.toStringAsFixed(2)}", Colors.grey),
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.discount, "Descuento (-${descuentoPorcentaje.toInt()}%)", "-Bs. ${descuentoMonto.toStringAsFixed(2)}", premiumColor),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                    ],
                    
                    _buildInfoRow(
                      Icons.attach_money, 
                      descuentoMonto > 0 ? "Total a pagar" : "Costo estimado", 
                      "Bs. ${tarifaFinal.toStringAsFixed(2)}", 
                      successColor
                    ),
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
                        // ACTUALIZAR INFORMACIÓN PREMIUM DESPUÉS DE CREAR VIAJE
                        await _verificarPlanPremium();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    descuentoMonto > 0 
                                      ? '¡Viaje solicitado con descuento premium!'
                                      : '¡Viaje solicitado con éxito!'
                                  ),
                                ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        descuentoMonto > 0 ? "Confirmar con descuento" : "Confirmar viaje",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
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

  // NUEVA FUNCIÓN: Widget para mostrar estado premium
  Widget _buildPremiumBanner() {
    if (!tienePlanPremium) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Premium activo • $viajesRestantes viajes restantes",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "-15%",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
              // NUEVO: Banner premium
              _buildPremiumBanner(),
              
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