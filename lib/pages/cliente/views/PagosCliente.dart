import 'package:flutter/material.dart';
import 'package:v_app/services/membresia_service.dart';

class PagosCliente extends StatefulWidget {
  const PagosCliente({super.key});

  @override
  State<PagosCliente> createState() => _PagosClienteState();
}

class _PagosClienteState extends State<PagosCliente> {
  Map<String, dynamic>? planInfo;
  bool isLoading = true;
  bool tienePlan = false;

  // Colores consistentes
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color premiumColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _cargarInfoPlan();
  }

  Future<void> _cargarInfoPlan() async {
    print('🔄 PagosCliente: Cargando información del plan');
    
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final info = await MembresiaService.obtenerInfoPlan();
      final verificacion = await MembresiaService.verificarPlanPremium();
      
      if (mounted) {
        setState(() {
          planInfo = info;
          tienePlan = verificacion['activo'] ?? false;
          isLoading = false;
        });
        print('✅ PagosCliente: Información cargada. Tiene plan: $tienePlan');
      }
    } catch (e) {
      print('❌ PagosCliente: Error al cargar info del plan: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _mostrarMensaje('Error al cargar información del plan', errorColor);
      }
    }
  }

  Future<void> _activarPlanPremium() async {
    print('🚀 PagosCliente: Iniciando activación de plan premium');
    
    // Mostrar modal de confirmación con QR
    final bool? confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildQRPaymentDialog(),
    );

    if (confirmado == true) {
      if (!mounted) return;
      
      setState(() => isLoading = true);
      
      try {
        print('💳 PagosCliente: Procesando pago...');
        final exito = await MembresiaService.activarPlanPremium();
        
        if (!mounted) return;
        
        if (exito) {
          print('✅ PagosCliente: Plan activado exitosamente');
          _mostrarMensaje('¡Plan Premium activado con éxito!', successColor);
          await _cargarInfoPlan(); // Recargar información
        } else {
          print('❌ PagosCliente: Falló la activación del plan');
          _mostrarMensaje('Error al activar el plan. Intenta de nuevo.', errorColor);
          setState(() => isLoading = false);
        }
      } catch (e) {
        print('❌ PagosCliente: Excepción al activar plan: $e');
        if (mounted) {
          _mostrarMensaje('Error inesperado: $e', errorColor);
          setState(() => isLoading = false);
        }
      }
    }
  }

  Widget _buildQRPaymentDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: premiumColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.qr_code, color: premiumColor, size: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Pagar Plan Premium",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Información del plan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildPlanFeature(Icons.discount, "15% de descuento en todos los viajes"),
                  const SizedBox(height: 8),
                  _buildPlanFeature(Icons.timer, "Válido por 30 días"),
                  const SizedBox(height: 8),
                  _buildPlanFeature(Icons.confirmation_number, "Hasta 60 viajes con descuento"),
                  const SizedBox(height: 8),
                  _buildPlanFeature(Icons.directions_car, "2 viajes con descuento por día"),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Precio
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: premiumColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.attach_money, color: premiumColor, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    "299 Bs.",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: premiumColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // QR Code simulado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      size: 150,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Escanea este QR para pagar",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              "Una vez realizado el pago, presiona 'Confirmar Pago'",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: successColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            "Confirmar Pago",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: successColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Cargando información..."),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payment,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Métodos de Pago y Membresías",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Estado del plan
          if (tienePlan)
            _buildPlanActivoCard()
          else
            _buildPlanInactivoCard(),

          const SizedBox(height: 24),

          // Información del Plan Premium
          _buildPlanInfoCard(),
        ],
      ),
    );
  }

  Widget _buildPlanActivoCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: MembresiaService.verificarPlanPremium(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final DateTime fechaVencimiento = data['fecha_vencimiento'] ?? DateTime.now();
        final int viajesRestantes = data['viajes_restantes'] ?? 0;
        final int diasRestantes = fechaVencimiento.difference(DateTime.now()).inDays;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [premiumColor, premiumColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: premiumColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    "PLAN PREMIUM ACTIVO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildPremiumStat("Viajes restantes", "$viajesRestantes"),
                  ),
                  Expanded(
                    child: _buildPremiumStat("Días restantes", "$diasRestantes"),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Text(
                "Vence: ${_formatearFecha(fechaVencimiento)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanInactivoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 28),
              const SizedBox(width: 12),
              Text(
                "Sin Plan Premium",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Activa tu plan premium para obtener descuentos en tus viajes",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: premiumColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.workspace_premium, color: premiumColor, size: 28),
              ),
              const SizedBox(width: 16),
              const Text(
                "Plan Premium",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Beneficios
          _buildBenefit(Icons.percent, "15% de descuento en todos los viajes"),
          _buildBenefit(Icons.schedule, "Válido por 30 días desde la activación"),
          _buildBenefit(Icons.confirmation_number, "Hasta 60 viajes con descuento"),
          _buildBenefit(Icons.today, "Máximo 2 viajes con descuento por día"),
          
          const SizedBox(height: 24),
          
          // Precio y botón
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "299 Bs.",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: premiumColor,
                    ),
                  ),
                  Text(
                    "Pago único por 30 días",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              if (!tienePlan)
                ElevatedButton(
                  onPressed: _activarPlanPremium,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: premiumColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Activar Plan",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "✓ Activo",
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: successColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return "${fecha.day}/${fecha.month}/${fecha.year}";
  }
}