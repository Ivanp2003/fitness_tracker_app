import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servicio de Síntesis de Voz (Text-to-Speech)
///
/// Encapsula el uso de `flutter_tts` configurado en idioma español
/// con tono y velocidad estables.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  TtsService._internal();

  /// Inicializa el servicio configurando el idioma en español
  Future<void> init() async {
    if (_isInitialized) return;

    try {
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

  /// Reproduce el texto suministrado
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }
    try {
      await _flutterTts.stop(); // Detener cualquier reproducción en curso
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error al reproducir voz: $e");
    }
  }

  /// Detiene cualquier reproducción activa
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error al detener voz: $e");
    }
  }
}
