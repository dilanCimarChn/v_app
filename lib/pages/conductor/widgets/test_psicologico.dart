import 'package:flutter/material.dart';

class TestPsicologico extends StatefulWidget {
  const TestPsicologico({Key? key}) : super(key: key);

  @override
  _TestPsicologicoState createState() => _TestPsicologicoState();
}

class _TestPsicologicoState extends State<TestPsicologico> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _respuestas = [];
  bool _canContinue = false;

  final List<Map<String, dynamic>> _preguntas = [
    {
      'pregunta': '¿Cómo reaccionaría si un pasajero se vuelve agresivo en su vehículo?',
      'opciones': [
        'Me pondría nervioso y probablemente respondería de la misma manera',
        'Le pediría amablemente que se calme, y si persiste, detendría el vehículo en un lugar seguro',
        'Lo ignoraría completamente y seguiría conduciendo',
        'Llamaría inmediatamente a la policía sin intentar calmar la situación'
      ],
      'correcta': 1
    },
    {
      'pregunta': 'Si se encuentra en un tráfico intenso y va a llegar tarde a recoger un pasajero:',
      'opciones': [
        'Aceleraría y buscaría vías alternas sin importar las señales de tránsito',
        'Mantendría la calma, avisaría al pasajero sobre el retraso y respetaría las normas de tránsito',
        'Cancelaría el viaje para evitar la mala calificación',
        'Me enojaría y culparía a otros conductores por el tráfico'
      ],
      'correcta': 1
    },
    {
      'pregunta': 'Después de un día largo de trabajo, ¿qué haría si se siente muy cansado pero todavía le queda un viaje por hacer?',
      'opciones': [
        'Tomaría una bebida energizante y continuaría conduciendo',
        'Aceptaría el viaje pero conduciría más rápido para terminar pronto',
        'Cancelaría el viaje y explicaría la situación, priorizando la seguridad',
        'Realizaría el viaje pero me quejaría con el pasajero sobre mi cansancio'
      ],
      'correcta': 2
    },
    {
      'pregunta': 'Si un pasajero le pide que exceda el límite de velocidad porque tiene prisa:',
      'opciones': [
        'Lo haría para obtener una buena calificación',
        'Me negaría educadamente explicando la importancia de la seguridad y las normas de tránsito',
        'Aceleraría solo un poco más del límite permitido',
        'Le diría que si me da propina extra lo consideraría'
      ],
      'correcta': 1
    },
    {
      'pregunta': 'Cuando hay un cambio repentino en la ruta que debe seguir:',
      'opciones': [
        'Me confundo fácilmente y me pongo ansioso',
        'Me molesto y culpo al GPS o al pasajero',
        'Me adapto rápidamente y busco la mejor alternativa manteniendo la calma',
        'Ignoro el cambio y sigo la ruta original'
      ],
      'correcta': 2
    },
    {
      'pregunta': '¿Cómo maneja la presión cuando varios pasajeros hablan al mismo tiempo o le dan instrucciones contradictorias?',
      'opciones': [
        'Me estreso y les pido que se callen',
        'Mantengo la calma, pido que hablen uno a la vez y sigo las indicaciones del que solicitó el viaje',
        'Subo el volumen de la música para no escucharlos',
        'Ignoro a todos y sigo mi propio criterio sin consultarles'
      ],
      'correcta': 1
    },
    {
      'pregunta': 'Si comete un error al conducir:',
      'opciones': [
        'Negaría que fue mi error y culparía a otros conductores',
        'Lo ignoraría y seguiría como si nada hubiera pasado',
        'Me disculparía si es necesario y aprendería de la experiencia',
        'Me sentiría tan mal que probablemente dejaría de conducir por ese día'
      ],
      'correcta': 2
    },
    {
      'pregunta': 'Ante una situación donde otro conductor le insulta en el tráfico:',
      'opciones': [
        'Le devolvería el insulto y posiblemente iniciaría una confrontación',
        'Me bajaría del auto para hablar con él cara a cara',
        'Ignoraría la situación y seguiría mi camino con calma',
        'Llamaría a la policía inmediatamente'
      ],
      'correcta': 2
    },
    {
      'pregunta': 'Cuando un pasajero deja objetos olvidados en su vehículo:',
      'opciones': [
        'Lo consideraría mala suerte del pasajero y me quedaría con los objetos',
        'Reportaría inmediatamente los objetos encontrados y haría lo posible por devolverlos',
        'Solo devolvería los objetos si hay recompensa',
        'Ignoraría la situación esperando que el pasajero no se dé cuenta'
      ],
      'correcta': 1
    },
    {
      'pregunta': 'En su opinión, la característica más importante de un buen conductor es:',
      'opciones': [
        'Conocer todos los atajos de la ciudad',
        'Tener un vehículo lujoso y moderno',
        'Responsabilidad, paciencia y respeto por las normas de tránsito',
        'Capacidad para conducir a alta velocidad cuando sea necesario'
      ],
      'correcta': 2
    },
  ];

  void _seleccionarRespuesta(int index) {
    setState(() {
      _respuestas.add({
        'pregunta': _currentIndex,
        'respuesta': index,
        'correcta': _preguntas[_currentIndex]['correcta']
      });
      _canContinue = true;
    });
  }

  void _siguientePregunta() {
    if (_currentIndex < _preguntas.length - 1) {
      setState(() {
        _currentIndex++;
        _canContinue = false;
      });
    } else {
      _mostrarResultado();
    }
  }

  void _mostrarResultado() {
    int correctas = 0;
    for (var respuesta in _respuestas) {
      if (respuesta['respuesta'] == respuesta['correcta']) {
        correctas++;
      }
    }

    final porcentaje = (correctas / _preguntas.length) * 100;
    final aprobado = porcentaje >= 70;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          aprobado ? '¡Test Aprobado!' : 'Test No Aprobado',
          style: TextStyle(
            color: aprobado ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Has respondido correctamente $correctas de ${_preguntas.length} preguntas.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Porcentaje: ${porcentaje.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Icon(
              aprobado ? Icons.check_circle : Icons.cancel,
              color: aprobado ? Colors.green : Colors.red,
              size: 60,
            ),
          ],
        ),
        actions: [
          if (!aprobado)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentIndex = 0;
                  _respuestas.clear();
                  _canContinue = false;
                });
              },
              child: const Text('Reintentar'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(aprobado);
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pregunta = _preguntas[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Psicotécnico'),
        backgroundColor: const Color(0xFF2E3B4E),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progreso
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _preguntas.length,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E3B4E)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Pregunta ${_currentIndex + 1} de ${_preguntas.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3B4E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Pregunta
              Text(
                pregunta['pregunta'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Opciones
              Expanded(
                child: ListView.builder(
                  itemCount: pregunta['opciones'].length,
                  itemBuilder: (context, index) {
                    bool isSelected = _respuestas.isNotEmpty &&
                        _respuestas.last['pregunta'] == _currentIndex &&
                        _respuestas.last['respuesta'] == index;
                    
                    return Card(
                      elevation: isSelected ? 4 : 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected ? const Color(0xFFE1F0FF) : null,
                      child: InkWell(
                        onTap: () => _seleccionarRespuesta(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF2E3B4E)),
                                  color: isSelected ? const Color(0xFF2E3B4E) : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                                    : Center(child: Text('${index + 1}')),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  pregunta['opciones'][index],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Botón Continuar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canContinue ? _siguientePregunta : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3B4E),
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _currentIndex < _preguntas.length - 1 ? 'Siguiente' : 'Finalizar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}