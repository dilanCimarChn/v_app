import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesCliente extends StatefulWidget {
  const NotificacionesCliente({super.key});

  @override
  State<NotificacionesCliente> createState() => _NotificacionesClienteState();
}

class _NotificacionesClienteState extends State<NotificacionesCliente> {
  // Colores consistentes con el resto de la app
  static const Color primaryColor = Color.fromARGB(255, 8, 146, 42);
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
                'Notificaciones',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Contenido principal
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('viajes')
                    .where('cliente_id', isEqualTo: user.uid)
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
                          Icon(Icons.error_outline, size: 64, color: errorColor),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar las notificaciones',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No tienes notificaciones',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las notificaciones de tus viajes aparecerán aquí',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Generar notificaciones basadas en los viajes
                  final viajes = snapshot.data!.docs;
                  final notificaciones = _generarNotificaciones(viajes);

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notificaciones.length,
                    itemBuilder: (context, index) {
                      return _buildNotificacionCard(notificaciones[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _generarNotificaciones(List<QueryDocumentSnapshot> viajes) {
    List<Map<String, dynamic>> notificaciones = [];
    
    for (var viaje in viajes) {
      final data = viaje.data() as Map<String, dynamic>;
      final estado = data['estado'];
      final conductorNombre = data['conductor_nombre'] ?? 'Conductor';
      final fechaCreacion = data['fecha_creacion'] as Timestamp?;
      final fechaFinalizacion = data['fecha_finalizacion'] as Timestamp?;
      
      // Notificación según el estado del viaje
      switch (estado) {
        case 'pendiente':
          notificaciones.add({
            'tipo': 'pendiente',
            'titulo': 'Viaje solicitado',
            'mensaje': 'Tu viaje ha sido solicitado. Buscando conductor...',
            'icono': Icons.hourglass_empty,
            'color': warningColor,
            'fecha': fechaCreacion,
            'conductor': conductorNombre,
          });
          break;
          
        case 'aceptado':
          notificaciones.add({
            'tipo': 'aceptado',
            'titulo': '¡Viaje aceptado!',
            'mensaje': '$conductorNombre aceptó tu viaje. Se dirige hacia ti.',
            'icono': Icons.check_circle,
            'color': successColor,
            'fecha': fechaCreacion,
            'conductor': conductorNombre,
          });
          break;
          
        case 'en_curso':
          notificaciones.add({
            'tipo': 'en_curso',
            'titulo': 'Viaje en curso',
            'mensaje': 'Tu viaje con $conductorNombre está en progreso.',
            'icono': Icons.directions_car,
            'color': primaryColor,
            'fecha': fechaCreacion,
            'conductor': conductorNombre,
          });
          break;
          
        case 'finalizado':
          notificaciones.add({
            'tipo': 'finalizado',
            'titulo': 'Viaje completado',
            'mensaje': 'Tu viaje con $conductorNombre ha sido completado exitosamente.',
            'icono': Icons.flag,
            'color': successColor,
            'fecha': fechaFinalizacion ?? fechaCreacion,
            'conductor': conductorNombre,
          });
          
          // Notificación adicional si fue calificado
          if (data['calificacion_general'] != null) {
            notificaciones.add({
              'tipo': 'calificado',
              'titulo': 'Viaje calificado',
              'mensaje': 'Has calificado tu viaje con $conductorNombre. ¡Gracias por tu feedback!',
              'icono': Icons.star,
              'color': warningColor,
              'fecha': data['fecha_calificacion'] as Timestamp? ?? fechaFinalizacion ?? fechaCreacion,
              'conductor': conductorNombre,
            });
          }
          break;
          
        case 'cancelado':
          notificaciones.add({
            'tipo': 'cancelado',
            'titulo': 'Viaje cancelado',
            'mensaje': 'Tu viaje ha sido cancelado.',
            'icono': Icons.cancel,
            'color': errorColor,
            'fecha': fechaCreacion,
            'conductor': conductorNombre,
          });
          break;
      }
    }
    
    // Ordenar por fecha más reciente
    notificaciones.sort((a, b) {
      final fechaA = a['fecha'] as Timestamp?;
      final fechaB = b['fecha'] as Timestamp?;
      
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      
      return fechaB.compareTo(fechaA);
    });
    
    return notificaciones;
  }

  Widget _buildNotificacionCard(Map<String, dynamic> notificacion) {
    final tipo = notificacion['tipo'];
    final titulo = notificacion['titulo'];
    final mensaje = notificacion['mensaje'];
    final icono = notificacion['icono'];
    final color = notificacion['color'];
    final fecha = notificacion['fecha'] as Timestamp?;
    final conductor = notificacion['conductor'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono de notificación
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 24),
            ),
            
            const SizedBox(width: 16),
            
            // Contenido de la notificación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mensaje,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _formatearFecha(fecha),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Indicador de estado
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _esReciente(fecha) ? color : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
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

  bool _esReciente(Timestamp? timestamp) {
    if (timestamp == null) return false;
    
    final fecha = timestamp.toDate();
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    return diferencia.inHours < 24; // Consideramos reciente si es menor a 24 horas
  }
}