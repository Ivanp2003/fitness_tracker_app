import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/activity_status.dart';
import '../../domain/usecases/monitor_activity.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EVENTOS DEL BLOC
// ══════════════════════════════════════════════════════════════════════════════
abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

class StartTrackingRequested extends ActivityEvent {}

class StopTrackingRequested extends ActivityEvent {}

class SensorDataReceived extends ActivityEvent {
  final PhysicalStatus status;
  const SensorDataReceived(this.status);

  @override
  List<Object?> get props => [status];
}

class FallCountdownTicked extends ActivityEvent {}

class ResetEmergencyRequested extends ActivityEvent {}

// ══════════════════════════════════════════════════════════════════════════════
// ESTADOS DEL BLOC
// ══════════════════════════════════════════════════════════════════════════════
class ActivityState extends Equatable {
  final PhysicalStatus status;
  final int countdown;
  final bool isTracking;
  final String errorMessage;

  const ActivityState({
    required this.status,
    required this.countdown,
    required this.isTracking,
    required this.errorMessage,
  });

  factory ActivityState.initial() {
    return ActivityState(
      status: PhysicalStatus.initial(),
      countdown: 15,
      isTracking: false,
      errorMessage: '',
    );
  }

  ActivityState copyWith({
    PhysicalStatus? status,
    int? countdown,
    bool? isTracking,
    String? errorMessage,
  }) {
    return ActivityState(
      status: status ?? this.status,
      countdown: countdown ?? this.countdown,
      isTracking: isTracking ?? this.isTracking,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, countdown, isTracking, errorMessage];
}

// ══════════════════════════════════════════════════════════════════════════════
// IMPLEMENTACIÓN DEL BLOC
// ══════════════════════════════════════════════════════════════════════════════
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final MonitorActivity monitorActivity;
  final TtsService _ttsService = TtsService();

  StreamSubscription<PhysicalStatus>? _subscription;
  Timer? _debounceTimer;
  Timer? _countdownTimer;
  Timer? _sosTtsTimer;

  ActivityType? _pendingActivityType;
  ActivityType _currentOfficialActivity = ActivityType.stationary;

  ActivityBloc(this.monitorActivity) : super(ActivityState.initial()) {
    on<StartTrackingRequested>(_onStartTracking);
    on<StopTrackingRequested>(_onStopTracking);
    on<SensorDataReceived>(_onSensorDataReceived);
    on<FallCountdownTicked>(_onFallCountdownTicked);
    on<ResetEmergencyRequested>(_onResetEmergency);
  }

  Future<void> _onStartTracking(
    StartTrackingRequested event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(
      isTracking: true,
      errorMessage: '',
    ));

    // Inicializar servicio de voz
    await _ttsService.init();
    await _ttsService.speak("Iniciando monitoreo de actividad física.");

    // Suscribirse al caso de uso de sensores
    await _subscription?.cancel();
    _subscription = monitorActivity().listen((status) {
      add(SensorDataReceived(status));
    });
  }

  void _onStopTracking(
    StopTrackingRequested event,
    Emitter<ActivityState> emit,
  ) {
    _cleanupAllTimers();
    _subscription?.cancel();
    _ttsService.stop();

    emit(state.copyWith(
      isTracking: false,
      status: PhysicalStatus.initial(),
    ));
  }

  void _onSensorDataReceived(
    SensorDataReceived event,
    Emitter<ActivityState> emit,
  ) {
    final newStatus = event.status;

    // Si estamos en medio de una emergencia (impacto detectado o SOS confirmado),
    // ignoramos el procesamiento de actividad y pasos
    if (state.status.fallState != FallState.normal) {
      // Excepción: Si detectamos otro impacto fuerte pero ya estamos en alerta, lo ignoramos
      return;
    }

    // 1. GESTIÓN DE CAÍDAS (Impacto de 25 m/s²)
    if (newStatus.fallState == FallState.impactDetected) {
      _cleanupAllTimers(); // Detener debounce de actividad

      // Emitir el estado de impacto detectado con cuenta de 15 segundos
      emit(state.copyWith(
        status: state.status.copyWith(
          fallState: FallState.impactDetected,
          currentMagnitude: newStatus.currentMagnitude,
        ),
        countdown: 15,
      ));

      // Primer aviso inmediato por voz
      _ttsService.speak("Se ha detectado una posible caída. Por favor, confirme si se encuentra bien.");

      // Iniciar temporizador de cuenta regresiva
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        add(FallCountdownTicked());
      });
      return;
    }

    // 2. GESTIÓN DE PASOS (Actualización inmediata)
    // Emitimos pasos y magnitud cruda al instante en la UI para mantener el dinamismo
    emit(state.copyWith(
      status: state.status.copyWith(
        stepCount: newStatus.stepCount,
        currentMagnitude: newStatus.currentMagnitude,
      ),
    ));

    // 3. GESTIÓN DE ACTIVIDAD (Debounce de 3 segundos para el cambio)
    final candidateActivity = newStatus.activityType;

    if (candidateActivity != _currentOfficialActivity) {
      if (candidateActivity != _pendingActivityType) {
        // Cancelar timer de debounce previo e iniciar el nuevo
        _debounceTimer?.cancel();
        _pendingActivityType = candidateActivity;

        _debounceTimer = Timer(const Duration(seconds: 3), () {
          if (_pendingActivityType == candidateActivity) {
            _currentOfficialActivity = candidateActivity;
            add(SensorDataReceived(newStatus.copyWith(activityType: candidateActivity)));
          }
        });
      }
    } else {
      // El estado candidateActivity volvió al oficial, cancelar debounce pendiente
      if (_pendingActivityType != null) {
        _debounceTimer?.cancel();
        _pendingActivityType = null;
      }
    }

    // Si el estado de la actividad se consolidó oficialmente
    if (newStatus.activityType == _currentOfficialActivity && 
        newStatus.activityType != state.status.activityType) {
      
      emit(state.copyWith(
        status: state.status.copyWith(activityType: _currentOfficialActivity),
      ));

      // Avisar por voz solo cuando cambia el estado oficial estable
      String message = "";
      switch (_currentOfficialActivity) {
        case ActivityType.stationary:
          message = "Actividad cambiada a reposo.";
          break;
        case ActivityType.walking:
          message = "Actividad cambiada a caminando.";
          break;
        case ActivityType.running:
          message = "Actividad cambiada a corriendo.";
          break;
      }
      _ttsService.speak(message);
    }
  }

  void _onFallCountdownTicked(
    FallCountdownTicked event,
    Emitter<ActivityState> emit,
  ) {
    if (state.status.fallState != FallState.impactDetected) return;

    if (state.countdown > 1) {
      emit(state.copyWith(countdown: state.countdown - 1));
    } else {
      // La cuenta llegó a cero, confirmar emergencia SOS
      _countdownTimer?.cancel();
      
      emit(state.copyWith(
        status: state.status.copyWith(fallState: FallState.sosConfirmed),
        countdown: 0,
      ));

      // Bucle de voz de emergencia con pausa de 7 segundos (rango de 6-8s)
      _sosTtsTimer?.cancel();
      _speakSosAlert(); // Ejecución inmediata
      _sosTtsTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
        _speakSosAlert();
      });
    }
  }

  void _speakSosAlert() {
    _ttsService.speak("¡Emergencia! El usuario ha sufrido una caída y no responde.");
  }

  void _onResetEmergency(
    ResetEmergencyRequested event,
    Emitter<ActivityState> emit,
  ) {
    _cleanupAllTimers();
    _ttsService.stop();
    
    // Anunciar restablecimiento
    _ttsService.speak("Alerta cancelada. Retornando a monitoreo normal.");

    // Volver a estado normal restableciendo la detección de actividad
    _currentOfficialActivity = ActivityType.stationary;
    _pendingActivityType = null;

    emit(state.copyWith(
      status: state.status.copyWith(
        fallState: FallState.normal,
        activityType: ActivityType.stationary,
      ),
      countdown: 15,
    ));
  }

  void _cleanupAllTimers() {
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    _sosTtsTimer?.cancel();
  }

  @override
  Future<void> close() {
    _cleanupAllTimers();
    _subscription?.cancel();
    return super.close();
  }
}
