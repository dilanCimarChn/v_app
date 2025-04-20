import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MapaClienteWidget extends StatefulWidget {
  const MapaClienteWidget({super.key});

  @override
  State<MapaClienteWidget> createState() => _MapaClienteWidgetState();
}

class _MapaClienteWidgetState extends State<MapaClienteWidget> {
  MaplibreMapController? mapController;
  LatLng? ubicacionActual;

  final String mapStyleUrl = "https://demotiles.maplibre.org/style.json";

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    // Solicitar permiso con permission_handler
    var status = await Permission.location.request();

    if (!await Geolocator.isLocationServiceEnabled()) {
      print("❌ Servicio de ubicación desactivado");
      return;
    }

    if (status != PermissionStatus.granted) {
      print("❌ Permiso de ubicación denegado");
      return;
    }

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      ubicacionActual = LatLng(posicion.latitude, posicion.longitude);
    });

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(ubicacionActual!, 15),
      );

      mapController!.addSymbol(SymbolOptions(
        geometry: ubicacionActual!,
        iconImage: "marker-15",
        iconSize: 1.5,
      ));
    }
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

  @override
  Widget build(BuildContext context) {
    if (ubicacionActual == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MaplibreMap(
      styleString: 'https://api.maptiler.com/maps/outdoor-v2/style.json?key=Y2TaDOuaHgeijPZP0ZiP',
      initialCameraPosition: CameraPosition(
        target: ubicacionActual!,
        zoom: 14.0,
      ),
      onMapCreated: _onMapCreated,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      compassEnabled: true,
    );
  }
}
