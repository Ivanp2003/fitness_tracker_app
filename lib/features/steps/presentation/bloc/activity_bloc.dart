import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/activity_status.dart';
import '../../domain/usecases/monitor_activity.dart';
import '../../../history/domain/entities/activity_history.dart';
import '../../../history/domain/usecases/create_activity_record.dart';

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

class SaveHistorySuccess extends ActivityEvent {
  const SaveHistorySuccess();
}

class SaveHistoryFailed extends ActivityEvent {
  final String message;
  const SaveHistoryFailed(this.message);

  @override
  List<Object?> get props => [message];
}

// ══════════════════════════════════════════════════════════════════════════════
// ESTADOS DEL BLOC
// ══════════════════════════════════════════════════════════════════════════════
class ActivityState extends Equatable {
  final PhysicalStatus status;
  final int countdown;
  final bool isTracking;
  final String errorMessage;
  final String saveMessage;

  const ActivityState({
    required this.status,
    required this.countdown,
    required this.isTracking,
    required this.errorMessage,
    required this.saveMessage,
  });

  factory ActivityState.initial() {
    return ActivityState(
      status: PhysicalStatus.initial(),
      countdown: 15,
      isTracking: false,
      errorMessage: '',
      saveMessage: '',
    );
  }

  ActivityState copyWith({
    PhysicalStatus? status,
    int? countdown,
    bool? isTracking,
    String? errorMessage,
    String? saveMessage,
    bool clearSaveMessage = false,
  }) {
    return ActivityState(
      status: status ?? this.status,
      countdown: countdown ?? this.countdown,
      isTracking: isTracking ?? this.isTracking,
      errorMessage: errorMessage ?? this.errorMessage,
      saveMessage: clearSaveMessage ? '' : (saveMessage ?? this.saveMessage),
    );
  }

  @override
  List<Object?> get props => [status, countdown, isTracking, errorMessage, saveMessage];
}

// ══════════════════════════════════════════════════════════════════════════════
// IMPLEMENTACIÓN DEL BLOC
// ══════════════════════════════════════════════════════════════════════════════
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final MonitorActivity monitorActivity;
  final CreateActivityRecord createActivityRecord;
  final TtsService _ttsService = TtsService();

  StreamSubscription<PhysicalStatus>? _subscription;
  Timer? _countdownTimer;
  Timer? _sosTtsTimer;

  DateTime? _sessionStartTime;
  DateTime? _lastActivityChangeTime;
  Map<ActivityType, int> _activityTimeCounters = {};
  bool _fallDetectedInSession = false;

  ActivityBloc({
    required this.monitorActivity,
    required this.createActivityRecord,
  }) : super(ActivityState.initial()) {
    on<StartTrackingRequested>(_onStartTracking);
    on<StopTrackingRequested>(_onStopTracking);
    on<SensorDataReceived>(_onSensorDataReceived);
    on<FallCountdownTicked>(_onFallCountdownTicked);
    on<ResetEmergencyRequested>(_onResetEmergency);
    on<SaveHistorySuccess>(_onSaveHistorySuccess);
    on<SaveHistoryFailed>(_onSaveHistoryFailed);
  }

  Future<void> _onStartTracking(
    StartTrackingRequested event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(
      isTracking: true,
      errorMessage: '', // Limpiamos el error al iniciar
      status: PhysicalStatus.initial(),
    ));

    final now = DateTime.now();
    _sessionStartTime = now;
    _lastActivityChangeTime = now;
    _fallDetectedInSession = false;
    _activityTimeCounters = {
      ActivityType.stationary: 0,
      ActivityType.walking: 0,
      ActivityType.running: 0,
    };

    await _ttsService.init();

    await _subscription?.cancel();
    _subscription = monitorActivity().listen((status) {
      add(SensorDataReceived(status));
    });
  }

  Future<void> _onStopTracking(
    StopTrackingRequested event,
    Emitter<ActivityState> emit,
  ) async {
    _cleanupAllTimers();
    await _subscription?.cancel();
    _ttsService.stop();

    if (_sessionStartTime != null) {
      emit(state.copyWith(isTracking: false, saveMessage: 'Guardando actividad registrada...'));
      await _saveActivityRecordToHistory();
    } else {
      emit(state.copyWith(isTracking: false));
    }
  }

  Future<void> _saveActivityRecordToHistory() async {
    final now = DateTime.now();
    
    if (_lastActivityChangeTime != null) {
      final lastDuration = now.difference(_lastActivityChangeTime!).inSeconds;
      final currentAct = state.status.activityType;
      _activityTimeCounters[currentAct] = (_activityTimeCounters[currentAct] ?? 0) + lastDuration;
    }

    ActivityType predominantType = ActivityType.stationary;
    int maxSeconds = 0;
    _activityTimeCounters.forEach((type, seconds) {
      if (seconds > maxSeconds) {
        maxSeconds = seconds;
        predominantType = type;
      }
    });

    final durationSeconds = now.difference(_sessionStartTime!).inSeconds;
    final totalSteps = state.status.stepCount;
    final estimatedCalories = totalSteps * 0.04;

    String typeString = 'reposo';
    if (predominantType == ActivityType.walking) typeString = 'caminar';
    if (predominantType == ActivityType.running) typeString = 'correr';

    final record = ActivityHistory(
      activityDate: _sessionStartTime!,
      durationSeconds: durationSeconds,
      primaryActivityType: typeString,
      totalSteps: totalSteps,
      estimatedCalories: estimatedCalories,
      fallDetected: _fallDetectedInSession,
    );

    _sessionStartTime = null;
    _lastActivityChangeTime = null;

    await _saveWithRetry(record);
  }

  Future<void> _saveWithRetry(ActivityHistory record) async {
    try {
      await createActivityRecord(record);
      add(const SaveHistorySuccess());
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('Error guardando actividad: $errorStr');
      if (errorStr.contains('SocketException') || errorStr.contains('Failed host lookup')) {
        add(const SaveHistoryFailed('Sin conexión a internet. Verifica tu red.'));
      } else if (errorStr.contains('AUTH')) {
        try {
          await Supabase.instance.client.auth.signInAnonymously();
          await createActivityRecord(record);
          add(const SaveHistorySuccess());
          return;
        } catch (e2) {
          final e2Str = e2.toString();
          if (e2Str.contains('SocketException') || e2Str.contains('Failed host lookup')) {
            add(const SaveHistoryFailed('Sin conexión a internet. Verifica tu red.'));
          } else {
            add(SaveHistoryFailed('Error de sesión: $e2Str'));
          }
          return;
        }
      } else if (errorStr.contains('NETWORK')) {
        add(const SaveHistoryFailed('No se pudo guardar: revisa tu conexión'));
      } else {
        add(SaveHistoryFailed('Error al guardar: $errorStr'));
      }
    }
  }

  void _onSaveHistorySuccess(SaveHistorySuccess event, Emitter<ActivityState> emit) {
    emit(state.copyWith(clearSaveMessage: true, saveMessage: ''));
  }

  void _onSaveHistoryFailed(SaveHistoryFailed event, Emitter<ActivityState> emit) {
    emit(state.copyWith(errorMessage: event.message, clearSaveMessage: true));
  }

  void _onSensorDataReceived(
    SensorDataReceived event,
    Emitter<ActivityState> emit,
  ) {
    final newStatus = event.status;

    if (state.status.fallState != FallState.normal) {
      return;
    }

    // 1. GESTIÓN DE CAÍDAS
    if (newStatus.fallState == FallState.impactDetected) {
      _fallDetectedInSession = true;
      _cleanupAllTimers();
      
      if (_lastActivityChangeTime != null) {
        final now = DateTime.now();
        final duration = now.difference(_lastActivityChangeTime!).inSeconds;
        final currentAct = state.status.activityType;
        _activityTimeCounters[currentAct] = (_activityTimeCounters[currentAct] ?? 0) + duration;
        _lastActivityChangeTime = null; 
      }

      emit(state.copyWith(
        status: state.status.copyWith(
          fallState: FallState.impactDetected,
          currentMagnitude: newStatus.currentMagnitude,
        ),
        countdown: 15,
      ));

      _ttsService.speak("Se ha detectado una posible caída. Por favor, confirme si se encuentra bien.");

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        add(FallCountdownTicked());
      });
      return;
    }

    // 2. GESTIÓN DE ACTIVIDAD
    final oldActivity = state.status.activityType;
    final newActivity = newStatus.activityType;

    emit(state.copyWith(status: newStatus));

    if (newActivity != oldActivity && _lastActivityChangeTime != null) {
      final now = DateTime.now();
      final duration = now.difference(_lastActivityChangeTime!).inSeconds;
      
      _activityTimeCounters[oldActivity] = (_activityTimeCounters[oldActivity] ?? 0) + duration;
      _lastActivityChangeTime = now;

      String message = "";
      switch (newActivity) {
        case ActivityType.stationary: message = "detenido"; break;
        case ActivityType.walking: message = "caminando"; break;
        case ActivityType.running: message = "corriendo"; break;
      }
      _ttsService.speak(message);
    }
  }

  void _onFallCountdownTicked(FallCountdownTicked event, Emitter<ActivityState> emit) {
    if (state.status.fallState != FallState.impactDetected) return;

    if (state.countdown > 1) {
      emit(state.copyWith(countdown: state.countdown - 1));
    } else {
      _fallDetectedInSession = true; 
      _countdownTimer?.cancel();
      
      emit(state.copyWith(
        status: state.status.copyWith(fallState: FallState.sosConfirmed),
        countdown: 0,
      ));

      _sosTtsTimer?.cancel();
      _speakSosAlert();
      _sosTtsTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
        _speakSosAlert();
      });
    }
  }

  void _speakSosAlert() {
    _ttsService.speak("¡Emergencia! El usuario ha sufrido una caída y no responde.");
  }

  void _onResetEmergency(ResetEmergencyRequested event, Emitter<ActivityState> emit) {
    _cleanupAllTimers();
    _ttsService.stop();

    if (_sessionStartTime != null) {
      _lastActivityChangeTime = DateTime.now();
    }

    emit(state.copyWith(
      status: state.status.copyWith(
        fallState: FallState.normal,
        activityType: ActivityType.stationary, 
      ),
      countdown: 15,
    ));
  }

  void _cleanupAllTimers() {
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
