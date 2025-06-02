import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComentariosCliente extends StatefulWidget {
  const ComentariosCliente({super.key});

  @override
  State<ComentariosCliente> createState() => _ComentariosClienteState();
}

class _ComentariosClienteState extends State<ComentariosCliente> {
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
          child: Text('Por favor, inicia sesión para ver tus calificaciones'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header personalizado sin flecha atrás
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
                'Mis Comentarios y Calificaciones',
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
                    .where('estado', isEqualTo: 'finalizado')
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
                            'Error al cargar las calificaciones',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verifica tu conexión a internet',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
                          Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'Aún no tienes viajes calificados',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tus calificaciones aparecerán aquí después de completar viajes',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Ordenar manualmente los documentos por fecha
                  final viajes = snapshot.data!.docs.toList();
                  viajes.sort((a, b) {
                    final fechaA = (a.data() as Map<String, dynamic>)['fecha_finalizacion'] as Timestamp?;
                    final fechaB = (b.data() as Map<String, dynamic>)['fecha_finalizacion'] as Timestamp?;
                    
                    if (fechaA == null && fechaB == null) return 0;
                    if (fechaA == null) return 1;
                    if (fechaB == null) return -1;
                    
                    return fechaB.compareTo(fechaA); // Más recientes primero
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: viajes.length,
                    itemBuilder: (context, index) {
                      final doc = viajes[index];
                      final viaje = doc.data() as Map<String, dynamic>;
                      return _buildViajeCard(viaje, doc.id);
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

  // MÉTODO MODIFICADO: Ahora incluye el ID del documento y permite edición
  Widget _buildViajeCard(Map<String, dynamic> viaje, String viajeId) {
    final conductorNombre = viaje['conductor_nombre'] ?? 'Conductor';
    final distancia = viaje['distancia_km']?.toDouble() ?? 0.0;
    final tarifa = viaje['tarifa']?.toDouble() ?? 0.0;
    final calificacionGeneral = viaje['calificacion_general'] ?? 0;
    final calificacionPuntualidad = viaje['calificacion_puntualidad'] ?? 0;
    final comentario = viaje['comentario_cliente'] ?? '';
    final fechaFinalizacion = viaje['fecha_finalizacion'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con información del viaje
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.directions_car, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viaje con $conductorNombre',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearFecha(fechaFinalizacion),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Información del viaje
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.straighten, 'Distancia', '${distancia.toStringAsFixed(2)} km', warningColor),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.attach_money, 'Costo', 'Bs. ${tarifa.toStringAsFixed(2)}', successColor),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'Conductor', conductorNombre, primaryColor),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // CALIFICACIONES EDITABLES con más espacio
            Row(
              children: [
                Expanded(
                  child: _buildCalificacionEditable(
                    'Calificación\nGeneral', // Dividido en 2 líneas
                    calificacionGeneral,
                    warningColor,
                    viajeId,
                    'calificacion_general',
                  ),
                ),
                const SizedBox(width: 12), // Reducido de 16 a 12
                Expanded(
                  child: _buildCalificacionEditable(
                    'Puntualidad',
                    calificacionPuntualidad,
                    primaryColor,
                    viajeId,
                    'calificacion_puntualidad',
                  ),
                ),
              ],
            ),
            
            // Comentario (si existe) - SOLO LECTURA
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Tu comentario:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comentario,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Si no hay calificaciones
            if (calificacionGeneral == 0 && calificacionPuntualidad == 0) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: warningColor, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Este viaje aún no ha sido calificado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // MÉTODO CORREGIDO: Calificación editable sin overflow
  Widget _buildCalificacionEditable(String titulo, int calificacionActual, Color color, String viajeId, String campo) {
    return Container(
      padding: const EdgeInsets.all(12), // Reducido el padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11, // Reducido el tamaño
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // Permitir 2 líneas
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6), // Reducido el espacio
          
          // Estrellas editables más pequeñas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => _actualizarCalificacion(viajeId, campo, index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1), // Reducido
                  child: Icon(
                    index < calificacionActual ? Icons.star : Icons.star_border,
                    color: color,
                    size: 20, // Reducido de 24 a 20
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 4),
          Text(
            '$calificacionActual/5',
            style: TextStyle(
              fontSize: 11, // Reducido
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Indicador más pequeño
          const SizedBox(height: 2),
          Text(
            'Toca para editar',
            style: TextStyle(
              fontSize: 8, // Más pequeño
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // NUEVO MÉTODO: Actualizar calificación en Firebase
  Future<void> _actualizarCalificacion(String viajeId, String campo, int nuevaCalificacion) async {
    try {
      await FirebaseFirestore.instance
          .collection('viajes')
          .doc(viajeId)
          .update({
        campo: nuevaCalificacion,
        'fecha_ultima_edicion': FieldValue.serverTimestamp(),
      });

      // Mostrar feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Calificación actualizada: $nuevaCalificacion estrella${nuevaCalificacion != 1 ? 's' : ''}'),
            ],
          ),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Error al actualizar: $e'),
            ],
          ),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';
    
    final fecha = timestamp.toDate();
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    if (diferencia.inDays == 0) {
      return 'Hoy a las ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diferencia.inDays == 1) {
      return 'Ayer a las ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diferencia.inDays < 7) {
      return '${diferencia.inDays} días atrás';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}