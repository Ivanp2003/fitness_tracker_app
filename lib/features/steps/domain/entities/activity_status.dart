import 'package:equatable/equatable.dart';

/// Clasificación de la actividad física del usuario
enum ActivityType {
  stationary, // Quieto / En reposo
  walking,    // Caminando
  running,    // Corriendo
}

/// Estado de emergencia por caída
enum FallState {
  normal,          // Sin incidentes
  impactDetected,  // Se detectó impacto, mostrando diálogo de advertencia
  sosConfirmed,    // Alerta de emergencia confirmada tras 15 segundos sin respuesta
}

/// Información del estado de seguimiento de movimiento
class PhysicalStatus extends Equatable {
  final ActivityType activityType;
  final FallState fallState;
  final int stepCount;
  final double currentMagnitude;

  const PhysicalStatus({
    required this.activityType,
    required this.fallState,
    required this.stepCount,
    required this.currentMagnitude,
  });

  /// Crear estado inicial por defecto
  factory PhysicalStatus.initial() {
    return const PhysicalStatus(
      activityType: ActivityType.stationary,
      fallState: FallState.normal,
      stepCount: 0,
      currentMagnitude: 9.8,
    );
  }

  /// Método copyWith para simplificar cambios parciales de estado
  PhysicalStatus copyWith({
    ActivityType? activityType,
    FallState? fallState,
    int? stepCount,
    double? currentMagnitude,
  }) {
    return PhysicalStatus(
      activityType: activityType ?? this.activityType,
      fallState: fallState ?? this.fallState,
      stepCount: stepCount ?? this.stepCount,
      currentMagnitude: currentMagnitude ?? this.currentMagnitude,
    );
  }

  @override
  List<Object?> get props => [activityType, fallState, stepCount, currentMagnitude];
}
