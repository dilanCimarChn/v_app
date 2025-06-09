import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistorialCliente extends StatefulWidget {
  const HistorialCliente({super.key});

  @override
  State<HistorialCliente> createState() => _HistorialClienteState();
}

class _HistorialClienteState extends State<HistorialCliente> {
  final user = FirebaseAuth.instance.currentUser;
  
  // Colores consistentes
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  String _getEstadoTexto(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      case 'en_curso':
        return 'En curso';
      case 'aceptado':
        return 'Aceptado';
      default:
        return 'Pendiente';
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
        return successColor;
      case 'cancelado':
        return errorColor;
      case 'en_curso':
        return warningColor;
      case 'aceptado':
        return primaryColor;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoEmoji(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
        return '✅';
      case 'cancelado':
        return '❌';
      case 'en_curso':
        return '🚗';
      case 'aceptado':
        return '👍';
      default:
        return '⏳';
    }
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje, String docId) {
    final fecha = (viaje['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now();
    final fechaFormateada = DateFormat('dd/MM/yyyy - HH:mm').format(fecha);
    final estado = viaje['estado'] ?? 'pendiente';
    final distancia = viaje['distancia_km']?.toDouble() ?? 0.0;
    final tarifa = viaje['tarifa']?.toDouble() ?? 0.0;
    final conductorNombre = viaje['conductor_nombre'] ?? 'Sin asignar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(estado).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getEstadoEmoji(estado),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEstadoTexto(estado),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _getEstadoColor(estado),
                          ),
                        ),
                        Text(
                          fechaFormateada,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "Bs. ${tarifa.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: successColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Información del viaje
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("📏", "Distancia", "${distancia.toStringAsFixed(1)} km"),
                  const SizedBox(height: 8),
                  _buildInfoRow("👤", "Conductor", conductorNombre),
                  if (viaje['comentarios'] != null && viaje['comentarios'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow("💬", "Comentarios", viaje['comentarios']),
                  ],
                ],
              ),
            ),
            
            // Acciones adicionales para viajes completados
// Reemplaza la sección de botones (líneas aproximadamente 190-230) con este código:

            if (estado.toLowerCase() == 'completado')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _mostrarDetallesViaje(viaje, docId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reducir padding
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Importante: evita que el Row se expanda
                          children: [
                            Text("ℹ️", style: TextStyle(fontSize: 14)), // Reducir tamaño del emoji
                            SizedBox(width: 4),
                            Flexible( // Usar Flexible para el texto
                              child: Text(
                                "Ver detalles",
                                style: TextStyle(fontSize: 12), // Reducir tamaño de fuente
                                overflow: TextOverflow.ellipsis, // Manejar overflow
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _repetirViaje(viaje),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: successColor,
                          side: BorderSide(color: successColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reducir padding
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Importante: evita que el Row se expanda
                          children: [
                            Text("🔄", style: TextStyle(fontSize: 14)), // Reducir tamaño del emoji
                            SizedBox(width: 4),
                            Flexible( // Usar Flexible para el texto
                              child: Text(
                                "Repetir",
                                style: TextStyle(fontSize: 12), // Reducir tamaño de fuente
                                overflow: TextOverflow.ellipsis, // Manejar overflow
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _mostrarDetallesViaje(Map<String, dynamic> viaje, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            
            Text(
              "Detalles del Viaje",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Detalles completos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("", "Origen", "Lat: ${viaje['origen_lat']?.toStringAsFixed(4)}, Lng: ${viaje['origen_lng']?.toStringAsFixed(4)}"),
                  const SizedBox(height: 8),
                  _buildInfoRow("", "Destino", "Lat: ${viaje['destino_lat']?.toStringAsFixed(4)}, Lng: ${viaje['destino_lng']?.toStringAsFixed(4)}"),
                  const SizedBox(height: 8),
                  _buildInfoRow("", "ID del Viaje", docId),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Cerrar", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _repetirViaje(Map<String, dynamic> viaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Repetir Viaje"),
        content: const Text("¿Deseas solicitar un nuevo viaje con el mismo destino?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aquí puedes implementar la lógica para crear un nuevo viaje
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Funcionalidad de repetir viaje próximamente"),
                  backgroundColor: primaryColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasResumen(List<QueryDocumentSnapshot> viajes) {
    final viajesCompletados = viajes.where((v) => (v.data() as Map)['estado'] == 'completado').length;
    final viajesCancelados = viajes.where((v) => (v.data() as Map)['estado'] == 'cancelado').length;
    final totalGastado = viajes
        .where((v) => (v.data() as Map)['estado'] == 'completado')
        .fold(0.0, (sum, v) => sum + ((v.data() as Map)['tarifa']?.toDouble() ?? 0.0));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Tu Resumen de Viajes",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstadistica("Total", "${viajes.length}", "📊"),
              _buildEstadistica("Completados", "$viajesCompletados", "✅"),
              _buildEstadistica("Cancelados", "$viajesCancelados", "❌"),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("💰", style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  "Total gastado: Bs. ${totalGastado.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadistica(String label, String valor, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Usuario no autenticado"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Mi Historial de Viajes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('viajes')
            .where('cliente_id', isEqualTo: user!.uid)
            .orderBy('fecha_creacion', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("❌", style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    "Error al cargar el historial",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final viajes = snapshot.data?.docs ?? [];

          if (viajes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("📖", style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    "Aún no tienes viajes",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tus viajes aparecerán aquí",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              // Estadísticas resumen
              _buildEstadisticasResumen(viajes),
              
              // Lista de viajes
              ...viajes.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildViajeCard(data, doc.id);
              }).toList(),
              
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}