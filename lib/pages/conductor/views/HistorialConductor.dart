import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistorialConductor extends StatefulWidget {
  const HistorialConductor({super.key});

  @override
  State<HistorialConductor> createState() => _HistorialConductorState();
}

class _HistorialConductorState extends State<HistorialConductor> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  String _filtroSeleccionado = 'todos';
  
  // Colores consistentes
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final clienteNombre = viaje['cliente_nombre'] ?? 'Cliente';
    final duracionMinutos = viaje['duracion_minutos']?.toInt() ?? 0;

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
            // Header con estado y ganancia
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Bs. ${tarifa.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: successColor,
                      ),
                    ),
                    if (duracionMinutos > 0)
                      Text(
                        "${duracionMinutos} min",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Información del cliente y viaje
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("👤", "Cliente", clienteNombre),
                  const SizedBox(height: 8),
                  _buildInfoRow("📏", "Distancia", "${distancia.toStringAsFixed(1)} km"),
                  const SizedBox(height: 8),
                  _buildInfoRow("💰", "Ganancia", "Bs. ${(tarifa * 0.8).toStringAsFixed(2)}", isEarning: true),
                ],
              ),
            ),
            
            // Acciones para diferentes estados
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
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("ℹ️", style: TextStyle(fontSize: 16)),
                            SizedBox(width: 4),
                            Text("Ver detalles"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _generarRecibo(viaje, docId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: successColor,
                          side: BorderSide(color: successColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("🧾", style: TextStyle(fontSize: 16)),
                            SizedBox(width: 4),
                            Text("Recibo"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (estado.toLowerCase() == 'en_curso')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _completarViaje(docId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("🏁", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text("Marcar como completado", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value, {bool isEarning = false}) {
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isEarning ? successColor : null,
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
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("🆔", "ID del Viaje", docId),
                  const SizedBox(height: 8),
                  _buildInfoRow("👤", "Cliente", viaje['cliente_nombre'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildInfoRow("💵", "Tarifa Total", "Bs. ${viaje['tarifa']?.toStringAsFixed(2) ?? '0.00'}"),
                  const SizedBox(height: 8),
                  _buildInfoRow("📈", "Tu Ganancia", "Bs. ${((viaje['tarifa']?.toDouble() ?? 0.0) * 0.8).toStringAsFixed(2)}", isEarning: true),
                  const SizedBox(height: 8),
                  _buildInfoRow("🏢", "Comisión App", "Bs. ${((viaje['tarifa']?.toDouble() ?? 0.0) * 0.2).toStringAsFixed(2)}"),
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

  void _generarRecibo(Map<String, dynamic> viaje, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text("🧾", style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text("Recibo del Viaje"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: $docId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text("Cliente: ${viaje['cliente_nombre']}"),
            Text("Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format((viaje['fecha_creacion'] as Timestamp).toDate())}"),
            Text("Distancia: ${viaje['distancia_km']?.toStringAsFixed(1)} km"),
            Text("Tarifa: Bs. ${viaje['tarifa']?.toStringAsFixed(2)}"),
            Text("Tu ganancia: Bs. ${((viaje['tarifa']?.toDouble() ?? 0.0) * 0.8).toStringAsFixed(2)}", 
                 style: const TextStyle(fontWeight: FontWeight.bold, color: successColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recibo guardado (funcionalidad próximamente)"),
                  backgroundColor: successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: successColor),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _completarViaje(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Completar Viaje"),
        content: const Text("¿Confirmas que el viaje ha sido completado exitosamente?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('viajes').doc(docId).update({
                'estado': 'completado',
                'fecha_completado': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("¡Viaje marcado como completado!"),
                  backgroundColor: successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: successColor),
            child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasDetalladas(List<QueryDocumentSnapshot> viajes) {
    final viajesCompletados = viajes.where((v) => (v.data() as Map)['estado'] == 'completado').length;
    final viajesCancelados = viajes.where((v) => (v.data() as Map)['estado'] == 'cancelado').length;
    final viajesEnCurso = viajes.where((v) => (v.data() as Map)['estado'] == 'en_curso').length;
    
    final totalIngresos = viajes
        .where((v) => (v.data() as Map)['estado'] == 'completado')
        .fold(0.0, (sum, v) => sum + ((v.data() as Map)['tarifa']?.toDouble() ?? 0.0));
    
    final gananciasNetas = totalIngresos * 0.8; // 80% para el conductor
    final comisionApp = totalIngresos * 0.2; // 20% para la app
    
    final distanciaTotal = viajes
        .where((v) => (v.data() as Map)['estado'] == 'completado')
        .fold(0.0, (sum, v) => sum + ((v.data() as Map)['distancia_km']?.toDouble() ?? 0.0));

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
            "Resumen del Conductor",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Primera fila de estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstadistica("Total Viajes", "${viajes.length}", "📊"),
              _buildEstadistica("Completados", "$viajesCompletados", "✅"),
              _buildEstadistica("En Curso", "$viajesEnCurso", "🚗"),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Segunda fila de estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstadistica("Cancelados", "$viajesCancelados", "❌"),
              _buildEstadistica("Distancia", "${distanciaTotal.toStringAsFixed(1)} km", "📏"),
              _buildEstadistica("Promedio", viajesCompletados > 0 ? "Bs. ${(gananciasNetas / viajesCompletados).toStringAsFixed(0)}" : "Bs. 0", "📈"),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Información financiera
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Ingresos Totales:", style: TextStyle(color: Colors.white70)),
                    Text("Bs. ${totalIngresos.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tus Ganancias (80%):", style: TextStyle(color: Colors.white70)),
                    Text("Bs. ${gananciasNetas.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Comisión App (20%):", style: TextStyle(color: Colors.white70)),
                    Text("Bs. ${comisionApp.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70)),
                  ],
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltroChip('todos', 'Todos'),
                  _buildFiltroChip('completado', 'Completados'),
                  _buildFiltroChip('en_curso', 'En Curso'),
                  _buildFiltroChip('cancelado', 'Cancelados'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String filtro, String label) {
    final isSelected = _filtroSeleccionado == filtro;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtroSeleccionado = filtro;
          });
        },
        selectedColor: primaryColor.withOpacity(0.2),
        checkmarkColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildListaViajes() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('viajes')
          .where('conductor_id', isEqualTo: user!.uid)
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

        final todosLosViajes = snapshot.data?.docs ?? [];
        
        // Filtrar viajes según el filtro seleccionado
        final viajesFiltrados = _filtroSeleccionado == 'todos' 
            ? todosLosViajes
            : todosLosViajes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['estado'] == _filtroSeleccionado;
              }).toList();

        if (todosLosViajes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("🚕", style: TextStyle(fontSize: 64)),
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
                  "Los viajes que aceptes aparecerán aquí",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Estadísticas
            _buildEstadisticasDetalladas(todosLosViajes),
            
            // Filtros
            _buildFiltros(),
            
            // Lista de viajes filtrados
            if (viajesFiltrados.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    "No hay viajes con el filtro seleccionado",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...viajesFiltrados.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildViajeCard(data, doc.id);
              }).toList(),
            
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildResumenDiario() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('viajes')
          .where('conductor_id', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final viajes = snapshot.data?.docs ?? [];
        final viajesHoy = viajes.where((v) {
          final fecha = (v.data() as Map)['fecha_creacion'] as Timestamp?;
          if (fecha == null) return false;
          final fechaViaje = fecha.toDate();
          final hoy = DateTime.now();
          return fechaViaje.day == hoy.day && fechaViaje.month == hoy.month && fechaViaje.year == hoy.year;
        }).toList();

        final gananciaHoy = viajesHoy
            .where((v) => (v.data() as Map)['estado'] == 'completado')
            .fold(0.0, (sum, v) => sum + (((v.data() as Map)['tarifa']?.toDouble() ?? 0.0) * 0.8));

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "Resumen de Hoy",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResumenItem("Viajes", "${viajesHoy.length}", "🚗", primaryColor),
                  _buildResumenItem("Completados", "${viajesHoy.where((v) => (v.data() as Map)['estado'] == 'completado').length}", "✅", successColor),
                  _buildResumenItem("Ganancia", "Bs. ${gananciaHoy.toStringAsFixed(0)}", "💰", successColor),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumenItem(String label, String valor, String emoji, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // NUEVO MÉTODO: Solo viajes de hoy para la pestaña "Hoy"
  Widget _buildViajesDeHoy() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('viajes')
          .where('conductor_id', isEqualTo: user!.uid)
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
                  "Error al cargar los viajes de hoy",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final todosLosViajes = snapshot.data?.docs ?? [];
        
        // FILTRAR SOLO LOS VIAJES DE HOY
        final viajesHoy = todosLosViajes.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fecha = data['fecha_creacion'] as Timestamp?;
          if (fecha == null) return false;
          
          final fechaViaje = fecha.toDate();
          final hoy = DateTime.now();
          
          // Verificar si es del mismo día, mes y año
          return fechaViaje.day == hoy.day && 
                 fechaViaje.month == hoy.month && 
                 fechaViaje.year == hoy.year;
        }).toList();

        // Ordenar por fecha (más recientes primero)
        viajesHoy.sort((a, b) {
          final fechaA = (a.data() as Map)['fecha_creacion'] as Timestamp?;
          final fechaB = (b.data() as Map)['fecha_creacion'] as Timestamp?;
          
          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;
          
          return fechaB.compareTo(fechaA);
        });

        if (viajesHoy.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("📅", style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  "No tienes viajes hoy",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Los viajes de hoy aparecerán aquí",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Lista de viajes de hoy
            ...viajesHoy.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildViajeCard(data, doc.id);
            }).toList(),
            
            const SizedBox(height: 20),
          ],
        );
      },
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
          "Historial de Conductor",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: "📋 Viajes"),
            Tab(text: "📅 Hoy"),
            Tab(text: "📊 Estadísticas"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Lista de viajes
          ListView(
            children: [
              _buildListaViajes(),
            ],
          ),
          
          // Tab 2: Resumen del día - CORREGIDO
          ListView(
            children: [
              _buildResumenDiario(),
              _buildViajesDeHoy(), // ESTO CAMBIÓ - ahora solo muestra viajes de hoy
            ],
          ),
          
          // Tab 3: Estadísticas generales
          ListView(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('viajes')
                    .where('conductor_id', isEqualTo: user!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return _buildEstadisticasDetalladas(snapshot.data!.docs);
                  }
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}