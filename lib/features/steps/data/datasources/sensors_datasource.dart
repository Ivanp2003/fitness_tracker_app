import 'package:sensors_plus/sensors_plus.dart';

/// DataSource que encapsula el sensor físico usando el plugin `sensors_plus`
abstract class SensorsDataSource {
  /// Stream continuo de eventos del acelerómetro incluyendo la gravedad.
  Stream<AccelerometerEvent> get accelerometerEvents;
}

class SensorsDataSourceImpl implements SensorsDataSource {
  @override
  Stream<AccelerometerEvent> get accelerometerEvents {
    // Retorna el stream nativo de sensores_plus
    return accelerometerEventStream();
  }
}
