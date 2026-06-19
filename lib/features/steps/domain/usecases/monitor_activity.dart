import 'dart:math' as math;
import '../../domain/entities/activity_status.dart';
import '../../data/datasources/sensors_datasource.dart';

/// Caso de uso para monitorear la actividad física del usuario y detectar caídas
///
/// Procesa los datos crudos del acelerómetro aplicando:
/// - Cálculo de magnitud vectorial euclidiana.
/// - Promedio móvil para suavizado de ruido.
/// - Conteo de pasos basado en cruces por umbral.
/// - Clasificación de estado de movimiento con factor de confianza.
/// - Detección de impacto de caída si supera los 25 m/s².
class MonitorActivity {
  final SensorsDataSource dataSource;

  MonitorActivity(this.dataSource);

  Stream<PhysicalStatus> call() async* {
    int stepCount = 0;
    double lastMagnitude = 9.8;
    final List<double> magnitudeHistory = [];
    const int historySize = 10;
    ActivityType lastActivityType = ActivityType.stationary;
    int activityConfidence = 0;

    await for (final event in dataSource.accelerometerEvents) {
      final x = event.x;
      final y = event.y;
      final z = event.z;
      
      // 1. Magnitud Vectorial Resultante
      final magnitude = math.sqrt(x * x + y * y + z * z);

      // 2. Promedio Móvil para Suavizado de Ruido
      magnitudeHistory.add(magnitude);
      if (magnitudeHistory.length > historySize) {
        magnitudeHistory.removeAt(0);
      }
      final avgMagnitude = magnitudeHistory.reduce((a, b) => a + b) / magnitudeHistory.length;

      // 3. Algoritmo de Conteo de Pasos
      if (magnitude > 12.0 && lastMagnitude <= 12.0) {
        stepCount++;
      }
      lastMagnitude = magnitude;

      // 4. Clasificación del Tipo de Actividad
      ActivityType newActivityType;
      if (avgMagnitude < 10.5) {
        newActivityType = ActivityType.stationary;
      } else if (avgMagnitude < 13.5) {
        newActivityType = ActivityType.walking;
      } else {
        newActivityType = ActivityType.running;
      }

      // 5. Aplicar Factor de Confianza (Estabilidad de Estado)
      ActivityType finalActivityType = lastActivityType;
      if (newActivityType == lastActivityType) {
        activityConfidence++;
        if (activityConfidence >= 3) {
          finalActivityType = newActivityType;
        }
      } else {
        activityConfidence = 0;
      }
      lastActivityType = newActivityType;

      // 6. Detección de Impacto de Caída (Umbral de 25 m/s²)
      FallState fallState = FallState.normal;
      if (magnitude > 25.0) {
        fallState = FallState.impactDetected;
      }

      yield PhysicalStatus(
        activityType: finalActivityType,
        fallState: fallState,
        stepCount: stepCount,
        currentMagnitude: magnitude,
      );
    }
  }
}
