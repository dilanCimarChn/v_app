import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GananciasConductor extends StatefulWidget {
  const GananciasConductor({super.key});

  @override
  State<GananciasConductor> createState() => _GananciasConductorState();
}

class _GananciasConductorState extends State<GananciasConductor> {
  final user = FirebaseAuth.instance.currentUser;
  String periodoSeleccionado = 'diario';
  
  // Colores consistentes
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);

  Map<String, dynamic> _calcularGanancias(List<QueryDocumentSnapshot> viajes, String periodo) {
    final ahora = DateTime.now();
    DateTime fechaInicio;
    
    switch (periodo) {
      case 'diario':
        fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
        break;
      case 'semanal':
        fechaInicio = ahora.subtract(Duration(days: ahora.weekday - 1));
        fechaInicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
        break;
      case 'mensual':
        fechaInicio = DateTime(ahora.year, ahora.month, 1);
        break;
      case 'anual':
        fechaInicio = DateTime(ahora.year, 1, 1);
        break;
      default:
        fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
    }

    final viajesPeriodo = viajes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final fecha = data['fecha_creacion'] as Timestamp?;
      if (fecha == null) return false;
      
      final fechaViaje = fecha.toDate();
      return fechaViaje.isAfter(fechaInicio) || fechaViaje.isAtSameMomentAs(fechaInicio);
    }).toList();

    final viajesCompletados = viajesPeriodo.where((v) => 
        (v.data() as Map)['estado'] == 'completado').toList();

    final totalIngresos = viajesCompletados.fold(0.0, (sum, v) => 
        sum + ((v.data() as Map)['tarifa']?.toDouble() ?? 0.0));

    final gananciasNetas = totalIngresos * 0.8;
    final comisionApp = totalIngresos * 0.2;
    final distanciaTotal = viajesCompletados.fold(0.0, (sum, v) => 
        sum + ((v.data() as Map)['distancia_km']?.toDouble() ?? 0.0));

    return {
      'totalViajes': viajesPeriodo.length,
      'viajesCompletados': viajesCompletados.length,
      'totalIngresos': totalIngresos,
      'gananciasNetas': gananciasNetas,
      'comisionApp': comisionApp,
      'distanciaTotal': distanciaTotal,
      'promedioPorViaje': viajesCompletados.isNotEmpty ? gananciasNetas / viajesCompletados.length : 0.0,
    };
  }

  Widget _buildPeriodoSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildPeriodoChip('diario', 'Hoy', '📅'),
          _buildPeriodoChip('semanal', 'Semana', '📊'),
          _buildPeriodoChip('mensual', 'Mes', '📈'),
          _buildPeriodoChip('anual', 'Año', '🏆'),
        ],
      ),
    );
  }

  Widget _buildPeriodoChip(String periodo, String label, String emoji) {
    final isSelected = periodoSeleccionado == periodo;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            periodoSeleccionado = periodo;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: isSelected ? 20 : 16),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaGanancias(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [successColor, successColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: successColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text("💰", style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tus Ganancias",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getNombrePeriodo(),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            "Bs. ${stats['gananciasNetas'].toStringAsFixed(2)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${stats['viajesCompletados']} viajes completados",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNombrePeriodo() {
    switch (periodoSeleccionado) {
      case 'diario':
        return 'Hoy ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
      case 'semanal':
        return 'Esta semana';
      case 'mensual':
        return 'Este mes';
      case 'anual':
        return 'Este año';
      default:
        return 'Período seleccionado';
    }
  }

  Widget _buildDetallesFinancieros(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("📊", style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                "Detalles Financieros",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildDetalleRow("💵", "Ingresos Totales", "Bs. ${stats['totalIngresos'].toStringAsFixed(2)}", primaryColor),
          const SizedBox(height: 12),
          _buildDetalleRow("✅", "Tus Ganancias (80%)", "Bs. ${stats['gananciasNetas'].toStringAsFixed(2)}", successColor),
          const SizedBox(height: 12),
          _buildDetalleRow("🏢", "Comisión App (20%)", "Bs. ${stats['comisionApp'].toStringAsFixed(2)}", errorColor),
          const SizedBox(height: 12),
          _buildDetalleRow("📏", "Distancia Total", "${stats['distanciaTotal'].toStringAsFixed(1)} km", warningColor),
          const SizedBox(height: 12),
          _buildDetalleRow("📈", "Promedio por Viaje", "Bs. ${stats['promedioPorViaje'].toStringAsFixed(2)}", primaryColor),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String emoji, String label, String valor, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(emoji, style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildComparacionPerdidas(Map<String, dynamic> stats) {
    final ganancia = stats['gananciasNetas'];
    final perdida = stats['comisionApp'];
    final total = ganancia + perdida;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("⚖️", style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                "División de Ingresos",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Barra visual de ganancia vs comisión
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[200],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (ganancia * 100 / (total > 0 ? total : 1)).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: successColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Expanded(
                  flex: (perdida * 100 / (total > 0 ? total : 1)).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: errorColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: successColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("Tu parte (80%)", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bs. ${ganancia.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: successColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: errorColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("App (20%)", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bs. ${perdida.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetasYLogros(Map<String, dynamic> stats) {
    final gananciaDiaria = stats['gananciasNetas'];
    final metaDiaria = 100.0; // Meta ejemplo
    final progreso = (gananciaDiaria / metaDiaria).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("🎯", style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                "Meta del Día",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bs. ${gananciaDiaria.toStringAsFixed(2)} / Bs. ${metaDiaria.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                "${(progreso * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progreso >= 1.0 ? successColor : primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          LinearProgressIndicator(
            value: progreso,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progreso >= 1.0 ? successColor : primaryColor,
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (progreso >= 1.0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text("🎉", style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    "¡Meta alcanzada! ¡Excelente trabajo!",
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
          "Mis Ganancias",
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
                    "Error al cargar las ganancias",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final viajes = snapshot.data?.docs ?? [];
          final stats = _calcularGanancias(viajes, periodoSeleccionado);

          if (viajes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("💰", style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    "Aún no tienes ganancias",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Completa viajes para ver tus ganancias aquí",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              // Selector de período
              _buildPeriodoSelector(),
              
              // Tarjeta principal de ganancias
              _buildTarjetaGanancias(stats),
              
              // Comparación ganancia vs comisión app
              _buildComparacionPerdidas(stats),
              
              // Detalles financieros
              _buildDetallesFinancieros(stats),
              
              // Metas y logros (solo para período diario)
              if (periodoSeleccionado == 'diario')
                _buildMetasYLogros(stats),
              
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}