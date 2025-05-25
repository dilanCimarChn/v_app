import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // CONFIGURACIÓN GMAIL CON TU CONTRASEÑA
  static const String _smtpUsername = '2002dilanchoque@gmail.com';
  static const String _smtpPassword = 'thwk rpes cgcj loxj'; // Tu contraseña de aplicación
  
  static Future<bool> enviarCodigoVerificacion({
    required String email,
    required String codigo,
    required String nombre,
    required bool esNuevoUsuario,
  }) async {
    try {
      final smtpServer = gmail(_smtpUsername, _smtpPassword);

      final message = Message()
        ..from = Address(_smtpUsername, 'Viaje Seguro')
        ..recipients.add(email)
        ..subject = esNuevoUsuario 
            ? 'Verificación de registro - Viaje Seguro'
            : 'Código de verificación - Viaje Seguro'
        ..html = '''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    background-color: #FAF3E3; 
                    margin: 0; 
                    padding: 20px; 
                    line-height: 1.6;
                }
                .container { 
                    max-width: 600px; 
                    margin: 0 auto; 
                    background-color: white; 
                    border-radius: 15px; 
                    padding: 30px; 
                    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                }
                .header { 
                    text-align: center; 
                    color: #2E3B4E; 
                    margin-bottom: 30px; 
                    border-bottom: 3px solid #16C48F; 
                    padding-bottom: 20px;
                }
                .logo { 
                    font-size: 2.5em; 
                    margin-bottom: 10px; 
                }
                .code-container { 
                    background: linear-gradient(135deg, #16C48F, #0EA5E9);
                    border-radius: 15px; 
                    padding: 25px; 
                    text-align: center; 
                    margin: 25px 0; 
                    color: white;
                }
                .code { 
                    font-size: 36px; 
                    font-weight: bold; 
                    letter-spacing: 12px; 
                    background-color: rgba(255,255,255,0.2);
                    padding: 15px;
                    border-radius: 10px;
                    display: inline-block;
                }
                .warning { 
                    background-color: #fff3cd; 
                    border-left: 4px solid #ffc107; 
                    border-radius: 5px; 
                    padding: 15px; 
                    margin: 20px 0; 
                    color: #856404; 
                }
                .footer { 
                    text-align: center; 
                    color: #666; 
                    font-size: 12px; 
                    margin-top: 30px; 
                    border-top: 1px solid #eee;
                    padding-top: 20px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">🚗</div>
                    <h1>Viaje Seguro</h1>
                    <h2>${esNuevoUsuario ? '¡Bienvenido a bordo!' : 'Verificación de Seguridad'}</h2>
                </div>
                
                <p><strong>Hola $nombre,</strong></p>
                
                <p>${esNuevoUsuario 
                    ? '¡Gracias por unirte a Viaje Seguro! 🎉<br>Para completar tu registro y empezar a disfrutar de viajes seguros, necesitamos verificar tu identidad.'
                    : 'Hemos detectado un intento de inicio de sesión en tu cuenta desde un dispositivo. Por tu seguridad, necesitamos verificar que realmente eres tú. 🔐'}</p>
                
                <div class="code-container">
                    <p style="margin-top: 0;"><strong>🔑 Tu código de verificación:</strong></p>
                    <div class="code">$codigo</div>
                    <p style="margin-bottom: 0;"><small>⏱️ Válido por 5 minutos únicamente</small></p>
                </div>
                
                <div class="warning">
                    <strong>⚠️ Importante:</strong> Si no fuiste tú quien ${esNuevoUsuario ? 'se registró' : 'intentó iniciar sesión'}, 
                    <strong>ignora este email</strong> y considera cambiar tu contraseña por seguridad. 
                    Nunca compartas este código con nadie.
                </div>
                
                <p>Si tienes alguna pregunta o necesitas ayuda, puedes contactarnos respondiendo a este email.</p>
                
                <div class="footer">
                    <p><strong>Viaje Seguro</strong> - Tu compañero de confianza en cada trayecto</p>
                    <p>Este es un email automático de seguridad. Si no solicitaste este código, puedes ignorar este mensaje.</p>
                    <p>© 2025 Viaje Seguro. Todos los derechos reservados.</p>
                </div>
            </div>
        </body>
        </html>
        ''';

      final sendReport = await send(message, smtpServer);
      print('✅ Email enviado exitosamente: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('❌ Error enviando email: $e');
      return false;
    }
  }
}