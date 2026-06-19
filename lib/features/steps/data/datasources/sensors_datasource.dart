import 'package:sensors_plus/sensors_plus.dart';

/// DataSource que encapsula el sensor físico usando el plugin `sensors_plus`
abstract class SensorsDataSource {
  /// Stream continuo de eventos del acelerómetro incluyendo la gravedad.
  Stream<AccelerometerEvent> get accelerometerEvents;
}

class SensorsDataSourceImpl implements SensorsDataSource {
  @override
  Stream<AccelerometerEvent> get accelerometerEvents {
    // Retorna el stream nativo de sensores_plus con intervalo normal (5 Hz / 200ms)
    // para optimizar el consumo de batería y estabilizar las lecturas.
    return accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval);
  }
}
