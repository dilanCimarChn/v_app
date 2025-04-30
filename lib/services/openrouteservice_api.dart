import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class OpenRouteServiceAPI {
  static const String _apiKey = '5b3ce3597851110001cf62480f5b4689420347c7864557b741c491c7'; // tu API Key de OpenRoute
  static const String _directionsUrl = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson';
  static const String _autocompleteUrl = 'https://api.openrouteservice.org/geocode/autocomplete';

  /// 🚗 Obtiene la ruta real de calles y avenidas
  static Future<List<LatLng>> obtenerRuta({
    required LatLng origen,
    required LatLng destino,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_directionsUrl),
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'coordinates': [
            [origen.longitude, origen.latitude],
            [destino.longitude, destino.latitude],
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'] as List;
        
        List<LatLng> ruta = coordinates.map((p) => LatLng(p[1], p[0])).toList();
        return ruta;
      } else {
        print('❌ Error al obtener ruta: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión al obtener ruta: $e');
      return [];
    }
  }

  /// 🔎 Autocompleta direcciones basado en el texto ingresado
  static Future<List<Map<String, dynamic>>> autocompletarBusqueda(
    String texto,
    LatLng posicionActual,
  ) async {
    try {
      final url = '$_autocompleteUrl?text=$texto'
          '&focus.point.lat=${posicionActual.latitude}'
          '&focus.point.lon=${posicionActual.longitude}'
          '&api_key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resultados = data['features'] as List;

        return resultados.map((r) => {
          'nombre': r['properties']['label'], // Nombre visible
          'coordenadas': LatLng(
            r['geometry']['coordinates'][1],
            r['geometry']['coordinates'][0],
          ),
        }).toList();
      } else {
        print('❌ Error en autocompletado: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión en autocompletar: $e');
      return [];
    }
  }
}
