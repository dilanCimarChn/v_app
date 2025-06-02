import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesConductor extends StatefulWidget {
  const NotificacionesConductor({super.key});

  @override
  State<NotificacionesConductor> createState() => _NotificacionesConductorState();
}

class _NotificacionesConductorState extends State<NotificacionesConductor> {
  // Colores consistentes con el resto de la app
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Por favor, inicia sesión para ver tus notificaciones'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header personalizado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: const Text(
                'Notificaciones y Viajes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Contenido principal - Dos secciones
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Sección 1: Viajes pendientes para aceptar
                    _buildVijesPendientesSection(),
                    
                    // Sección 2: Historial de notificaciones
                    _buildHistorialNotificacionesSection(user.uid),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SECCIÓN 1: Viajes pendientes
  Widget _buildVijesPendientesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_taxi, color: warningColor, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Viajes Disponibles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Lista de viajes pendientes
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('viajes')
                .where('estado', isEqualTo: 'pendiente')
                .orderBy('fecha_creacion', descending: true)
                .limit(5) // Máximo 5 viajes pendientes
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No hay viajes disponibles en este momento',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final viajes = snapshot.data!.docs;
              
              return Column(
                children: viajes.map((doc) {
                  return _buildViajePendienteCard(doc);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // SECCIÓN 2: Historial de notificaciones
  Widget _buildHistorialNotificacionesSection(String conductorId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Historial de Actividad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Lista de notificaciones del conductor
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('viajes')
                .where('conductor_id', isEqualTo: conductorId)
                .orderBy('fecha_creacion', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No tienes actividad reciente',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final viajes = snapshot.data!.docs;
              final notificaciones = _generarNotificacionesConductor(viajes);

              return Column(
                children: notificaciones.map((notificacion) {
                  return _buildNotificacionCard(notificacion);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Card para viaje pendiente - SOLO VISUALIZACIÓN
  Widget _buildViajePendienteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final clienteNombre = data['cliente_nombre'] ?? 'Cliente';
    final distancia = data['distancia_km']?.toDouble() ?? 0.0;
    final tarifa = data['tarifa']?.toDouble() ?? 0.0;
    final fechaCreacion = data['fecha_creacion'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: warningColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del viaje
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, color: warningColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo viaje - $clienteNombre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatearFecha(fechaCreacion),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Detalles del viaje
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.straighten, 'Distancia', '${distancia.toStringAsFixed(2)} km', primaryColor),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.attach_money, 'Ganancia', 'Bs. ${tarifa.toStringAsFixed(2)}', successColor),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mensaje informativo en lugar de botones
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ve al mapa principal para aceptar viajes disponibles',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card de notificación normal
  Widget _buildNotificacionCard(Map<String, dynamic> notificacion) {
    final titulo = notificacion['titulo'];
    final mensaje = notificacion['mensaje'];
    final icono = notificacion['icono'];
    final color = notificacion['color'];
    final fecha = notificacion['fecha'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatearFecha(fecha),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // Generar notificaciones para conductor
  List<Map<String, dynamic>> _generarNotificacionesConductor(List<QueryDocumentSnapshot> viajes) {
    List<Map<String, dynamic>> notificaciones = [];
    
    for (var viaje in viajes) {
      final data = viaje.data() as Map<String, dynamic>;
      final estado = data['estado'];
      final clienteNombre = data['cliente_nombre'] ?? 'Cliente';
      final fechaCreacion = data['fecha_creacion'] as Timestamp?;
      final fechaFinalizacion = data['fecha_finalizacion'] as Timestamp?;
      final tarifa = data['tarifa']?.toDouble() ?? 0.0;
      
      switch (estado) {
        case 'aceptado':
          notificaciones.add({
            'titulo': 'Viaje aceptado',
            'mensaje': 'Aceptaste el viaje de $clienteNombre',
            'icono': Icons.check_circle,
            'color': successColor,
            'fecha': fechaCreacion,
          });
          break;
          
        case 'en_curso':
          notificaciones.add({
            'titulo': 'Viaje en progreso',
            'mensaje': 'Viaje con $clienteNombre en curso',
            'icono': Icons.directions_car,
            'color': primaryColor,
            'fecha': fechaCreacion,
          });
          break;
          
        case 'finalizado':
          notificaciones.add({
            'titulo': 'Viaje completado',
            'mensaje': 'Ganaste Bs. ${tarifa.toStringAsFixed(2)} por el viaje con $clienteNombre',
            'icono': Icons.flag,
            'color': successColor,
            'fecha': fechaFinalizacion ?? fechaCreacion,
          });
          break;
          
        case 'cancelado':
          notificaciones.add({
            'titulo': 'Viaje cancelado',
            'mensaje': 'El viaje con $clienteNombre fue cancelado',
            'icono': Icons.cancel,
            'color': errorColor,
            'fecha': fechaCreacion,
          });
          break;
      }
    }
    
    return notificaciones;
  }

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';
    
    final fecha = timestamp.toDate();
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    if (diferencia.inMinutes < 1) {
      return 'Ahora mismo';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays == 1) {
      return 'Ayer';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}