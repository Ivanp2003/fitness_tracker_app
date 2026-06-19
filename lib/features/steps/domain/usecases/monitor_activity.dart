import 'dart:math' as math;
import '../../domain/entities/activity_status.dart';
import '../../data/datasources/sensors_datasource.dart';

/// Caso de uso para monitorear la actividad física del usuario y detectar caídas
///
/// Procesa los datos crudos del acelerómetro aplicando:
/// - Cálculo de magnitud vectorial euclidiana.
/// - Promedio móvil para suavizado de ruido.
/// - Conteo de pasos basado en cruces por umbral.
/// - Registro de timestamps de pasos en una ventana deslizante de 4 segundos.
/// - Cálculo de cadencia en tiempo real en pasos por minuto (SPM).
/// - Detección rápida de reposo (stationary) si han transcurrido más de 1.3s desde el último paso.
/// - Clasificación de estado mediante límites de cadencia (con filtro de confianza de 3 muestras).
/// - Detección de caída en dos fases: Ingravidez (<3 m/s²) e impacto inmediato (>35 m/s²).
class MonitorActivity {
  final SensorsDataSource dataSource;

  // ══════════════════════════════════════════════════════════════════════════════
  // CONSTANTES DE CALIBRACIÓN (FÁCILMENTE AJUSTABLES)
  // ══════════════════════════════════════════════════════════════════════════════
  static const double cadenceLimitStationaryToWalking = 0.0;
  static const double cadenceLimitWalkingToRunning = 130.0;
  
  /// Tiempo límite sin pasos para forzar estado detenido/reposo (milisegundos)
  static const int stationaryTimeoutThresholdMs = 1300;

  MonitorActivity(this.dataSource);

  Stream<PhysicalStatus> call() async* {
    int stepCount = 0;
    double lastMagnitude = 9.8;
    final List<double> magnitudeHistory = [];
    const int historySize = 10;

    // Lista para rastrear los timestamps de los pasos dentro de la ventana de 4 segundos
    final List<DateTime> stepTimestamps = [];
    const Duration windowDuration = Duration(seconds: 4);

    // Guardar el timestamp del último paso detectado por separado
    DateTime? lastStepTime;

    // Variables de estabilidad de actividad (Muestras crudas vs. Confirmadas)
    ActivityType confirmedActivity = ActivityType.stationary;
    ActivityType candidateActivity = ActivityType.stationary;
    int activityConfidence = 0;

    // Historial para detección de caídas en dos fases (Ingravidez + Impacto)
    DateTime? lastFreeFallTime;

    await for (final event in dataSource.accelerometerEvents) {
      final x = event.x;
      final y = event.y;
      final z = event.z;
      
      // 1. Magnitud Vectorial Resultante
      final magnitude = math.sqrt(x * x + y * y + z * z);

      // 2. Promedio Móvil para Suavizado de Ruido (10 muestras)
      magnitudeHistory.add(magnitude);
      if (magnitudeHistory.length > historySize) {
        magnitudeHistory.removeAt(0);
      }
      final avgMagnitude = magnitudeHistory.reduce((a, b) => a + b) / magnitudeHistory.length;

      // 3. Algoritmo de Conteo de Pasos y Registro de Timestamps
      if (magnitude > 12.0 && lastMagnitude <= 12.0) {
        stepCount++;
        final stepTime = DateTime.now();
        stepTimestamps.add(stepTime);
        lastStepTime = stepTime;
      }
      lastMagnitude = magnitude;

      // 4. Limpieza de pasos antiguos fuera de la ventana de los últimos 4 segundos
      final now = DateTime.now();
      final cutoff = now.subtract(windowDuration);
      stepTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));

      // 5. Cálculo de Cadencia en Pasos por Minuto (SPM)
      final double cadence = stepTimestamps.length * 60.0 / windowDuration.inSeconds;

      // 6. Clasificación de Actividad basada en Cadencia y Detección Rápida de Detención
      ActivityType rawClassifiedActivity;

      final millisecondsSinceLastStep = lastStepTime != null
          ? now.difference(lastStepTime).inMilliseconds
          : null;

      if (millisecondsSinceLastStep != null &&
          millisecondsSinceLastStep > stationaryTimeoutThresholdMs) {
        // Forzar reposo inmediato si no hay pasos recientes
        rawClassifiedActivity = ActivityType.stationary;
      } else if (cadence <= cadenceLimitStationaryToWalking) {
        rawClassifiedActivity = ActivityType.stationary;
      } else if (cadence <= cadenceLimitWalkingToRunning) {
        rawClassifiedActivity = ActivityType.walking;
      } else {
        rawClassifiedActivity = ActivityType.running;
      }

      // MODO DEBUG TEMPORAL: Impresión de cadencia y delta de pasos en tiempo real
      // ignore: avoid_print
      print(
        'DEBUG FISICO - Cadencia: ${cadence.toStringAsFixed(1)} SPM | '
        'ms sin paso: ${millisecondsSinceLastStep ?? "N/A"} | '
        'Clasif. Cruda: ${rawClassifiedActivity.name} | '
        'Estado Confirmado: ${confirmedActivity.name} | '
        'Confianza: $activityConfidence/3'
      );

      // 7. Algoritmo del Factor de Confianza de Actividad (3 muestras consecutivas)
      if (rawClassifiedActivity != confirmedActivity) {
        if (rawClassifiedActivity == candidateActivity) {
          activityConfidence++;
          if (activityConfidence >= 3) {
            confirmedActivity = rawClassifiedActivity;
            activityConfidence = 0;
          }
        } else {
          candidateActivity = rawClassifiedActivity;
          activityConfidence = 1;
        }
      } else {
        candidateActivity = confirmedActivity;
        activityConfidence = 0;
      }

      // 8. Detección de Caída en Dos Fases
      // Fase A: Registro de caída libre / ingravidez (< 3.0 m/s²)
      if (magnitude < 3.0) {
        lastFreeFallTime = DateTime.now();
      }

      // Fase B: Registro de impacto fuerte (> 35.0 m/s²) posterior e inmediato (ventana < 1 segundo)
      FallState fallState = FallState.normal;
      if (magnitude > 35.0) {
        if (lastFreeFallTime != null) {
          final timeDifference = DateTime.now().difference(lastFreeFallTime);
          if (timeDifference.inMilliseconds < 1000) {
            fallState = FallState.impactDetected;
            lastFreeFallTime = null; // Consumir el evento
          }
        }
      }

      yield PhysicalStatus(
        activityType: confirmedActivity,
        fallState: fallState,
        stepCount: stepCount,
        currentMagnitude: magnitude,
        averageMagnitude: avgMagnitude,
        cadence: cadence,
      );
    }
  }
}
