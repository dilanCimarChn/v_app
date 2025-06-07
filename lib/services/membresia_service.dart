import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MembresiaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verificar si el cliente tiene plan premium activo
  static Future<Map<String, dynamic>> verificarPlanPremium() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ MembresiaService: Usuario no autenticado');
      return {'activo': false, 'viajes_restantes': 0};
    }

    try {
      print('🔍 MembresiaService: Verificando plan para usuario ${user.uid}');
      
      final doc = await _firestore
          .collection('planes_premium')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('📭 MembresiaService: No existe plan premium para este usuario');
        return {'activo': false, 'viajes_restantes': 0};
      }

      final data = doc.data()!;
      final DateTime fechaVencimiento = (data['fecha_vencimiento'] as Timestamp).toDate();
      final bool planActivo = data['plan_activo'] ?? false;
      final int viajesRestantes = data['viajes_restantes'] ?? 0;

      // Verificar si el plan sigue vigente
      final bool vigente = DateTime.now().isBefore(fechaVencimiento) && 
                          planActivo && 
                          viajesRestantes > 0;

      print('📊 MembresiaService: Plan activo: $planActivo, Viajes restantes: $viajesRestantes, Vigente: $vigente');

      if (!vigente && planActivo) {
        // Desactivar plan si venció o se agotaron los viajes
        await _firestore.collection('planes_premium').doc(user.uid).update({
          'plan_activo': false,
        });
        print('⏰ MembresiaService: Plan desactivado por vencimiento');
      }

      return {
        'activo': vigente,
        'viajes_restantes': viajesRestantes,
        'fecha_vencimiento': fechaVencimiento,
        'fecha_activacion': (data['fecha_activacion'] as Timestamp).toDate(),
      };
    } catch (e) {
      print('❌ MembresiaService: Error al verificar plan premium: $e');
      return {'activo': false, 'viajes_restantes': 0};
    }
  }

  // Activar plan premium
  static Future<bool> activarPlanPremium() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ MembresiaService: No hay usuario autenticado para activar plan');
      return false;
    }

    try {
      print('🚀 MembresiaService: Iniciando activación de plan premium para ${user.uid}');
      
      // Obtener datos del usuario
      DocumentSnapshot? userDoc;
      String nombreCliente = 'Cliente';
      String emailCliente = user.email ?? '';

      // Intentar obtener datos del usuario
      try {
        userDoc = await _firestore
            .collection('usuario-app')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          nombreCliente = userData['name'] ?? 'Cliente';
          emailCliente = userData['email'] ?? user.email ?? '';
        } else {
          print('⚠️ MembresiaService: Documento de usuario no encontrado, usando datos básicos');
        }
      } catch (e) {
        print('⚠️ MembresiaService: Error al obtener datos del usuario: $e');
        // Continuar con datos básicos
      }

      final DateTime fechaActivacion = DateTime.now();
      final DateTime fechaVencimiento = fechaActivacion.add(const Duration(days: 30));

      final Map<String, dynamic> planData = {
        'cliente_id': user.uid,
        'nombre_cliente': nombreCliente,
        'email_cliente': emailCliente,
        'plan_activo': true,
        'fecha_activacion': Timestamp.fromDate(fechaActivacion),
        'fecha_vencimiento': Timestamp.fromDate(fechaVencimiento),
        'viajes_restantes': 60,
        'viajes_usados': 0,
        'descuento_porcentaje': 15,
        'precio_plan': 299.0,
        'fecha_pago': FieldValue.serverTimestamp(),
      };

      print('💾 MembresiaService: Guardando plan premium en Firestore');

      await _firestore
          .collection('planes_premium')
          .doc(user.uid)
          .set(planData);

      print('✅ MembresiaService: Plan premium activado correctamente');
      return true;
      
    } catch (e) {
      print('❌ MembresiaService: Error al activar plan premium: $e');
      return false;
    }
  }

  // Usar un viaje del plan premium
  static Future<bool> usarViajePremium() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ MembresiaService: No hay usuario para usar viaje premium');
      return false;
    }

    try {
      final docRef = _firestore.collection('planes_premium').doc(user.uid);
      
      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          print('❌ MembresiaService: No existe plan premium para usar viaje');
          return false;
        }
        
        final data = doc.data()!;
        final int viajesRestantes = data['viajes_restantes'] ?? 0;
        final int viajesUsados = data['viajes_usados'] ?? 0;
        
        if (viajesRestantes <= 0) {
          print('❌ MembresiaService: No hay viajes restantes en el plan');
          return false;
        }
        
        transaction.update(docRef, {
          'viajes_restantes': viajesRestantes - 1,
          'viajes_usados': viajesUsados + 1,
          'ultimo_viaje_premium': FieldValue.serverTimestamp(),
        });
        
        print('✅ MembresiaService: Viaje premium usado. Restantes: ${viajesRestantes - 1}');
        return true;
      });
    } catch (e) {
      print('❌ MembresiaService: Error al usar viaje premium: $e');
      return false;
    }
  }

  // Obtener información completa del plan
  static Future<Map<String, dynamic>?> obtenerInfoPlan() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ MembresiaService: No hay usuario para obtener info del plan');
      return null;
    }

    try {
      final doc = await _firestore
          .collection('planes_premium')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('📭 MembresiaService: No existe plan premium para este usuario');
        return null;
      }

      print('✅ MembresiaService: Información del plan obtenida correctamente');
      return doc.data();
    } catch (e) {
      print('❌ MembresiaService: Error al obtener info del plan: $e');
      return null;
    }
  }
}