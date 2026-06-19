import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servicio de Síntesis de Voz (Text-to-Speech)
///
/// Encapsula el uso de `flutter_tts` configurado en idioma español.
/// Implementa una cola secuencial asíncrona para evitar el solapamiento de frases.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  // Cola secuencial de reproducción de audio
  Future<void> _speakingFuture = Future.value();

  TtsService._internal();

  /// Inicializa el servicio configurando el idioma en español y activando el await completion
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Configurar para esperar a que finalice la frase actual antes de resolver el Future
      await _flutterTts.awaitSpeakCompletion(true);

      // Intentar establecer el idioma en español (España/México)
      bool isLanguageAvailable = await _flutterTts.isLanguageAvailable("es-ES") as bool;
      if (isLanguageAvailable) {
        await _flutterTts.setLanguage("es-ES");
      } else {
        await _flutterTts.setLanguage("es-MX");
      }

      await _flutterTts.setSpeechRate(0.5); // Velocidad moderada
      await _flutterTts.setPitch(1.0);      // Tono natural
      await _flutterTts.setVolume(1.0);     // Volumen al máximo

      _isInitialized = true;
    } catch (e) {
      debugPrint("Error inicializando TtsService: $e");
    }
  }

  /// Reproduce el texto suministrado encolándolo secuencialmente
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }

    // Encadenar secuencialmente la nueva reproducción en la cola
    _speakingFuture = _speakingFuture.then((_) async {
      try {
        await _flutterTts.speak(text);
      } catch (e) {
        debugPrint("Error al reproducir voz: $e");
      }
    });

    // Esperar a que se complete el turno de reproducción
    await _speakingFuture;
  }

  /// Detiene cualquier reproducción activa y vacía la cola
  Future<void> stop() async {
    try {
      _speakingFuture = Future.value(); // Vaciar y resetear la cola de reproducción
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error al detener voz: $e");
    }
  }
}
