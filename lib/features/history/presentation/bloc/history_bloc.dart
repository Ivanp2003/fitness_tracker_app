import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_activity_history.dart';
import '../../domain/usecases/create_activity_record.dart';
import '../../domain/usecases/update_activity_record.dart';
import '../../domain/usecases/delete_activity_record.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final GetActivityHistory getActivityHistory;
  final CreateActivityRecord createActivityRecord;
  final UpdateActivityRecord updateActivityRecord;
  final DeleteActivityRecord deleteActivityRecord;

  HistoryBloc({
    required this.getActivityHistory,
    required this.createActivityRecord,
    required this.updateActivityRecord,
    required this.deleteActivityRecord,
  }) : super(HistoryInitialState()) {
    on<LoadHistoryEvent>(_onLoadHistory);
    on<AddActivityEvent>(_onAddActivity);
    on<UpdateActivityEvent>(_onUpdateActivity);
    on<DeleteActivityEvent>(_onDeleteActivity);
  }

  Future<void> _onLoadHistory(LoadHistoryEvent event, Emitter<HistoryState> emit) async {
    emit(HistoryLoadingState());
    try {
      final history = await getActivityHistory();
      emit(HistoryLoadedState(history));
    } catch (e) {
      _handleError(e, emit);
    }
  }

  Future<void> _onAddActivity(AddActivityEvent event, Emitter<HistoryState> emit) async {
    emit(HistoryLoadingState());
    try {
      await createActivityRecord(event.activity);
      add(LoadHistoryEvent());
    } catch (e) {
      _handleError(e, emit);
    }
  }

  Future<void> _onUpdateActivity(UpdateActivityEvent event, Emitter<HistoryState> emit) async {
    emit(HistoryLoadingState());
    try {
      await updateActivityRecord(event.activity);
      add(LoadHistoryEvent());
    } catch (e) {
      _handleError(e, emit);
    }
  }

  Future<void> _onDeleteActivity(DeleteActivityEvent event, Emitter<HistoryState> emit) async {
    emit(HistoryLoadingState());
    try {
      await deleteActivityRecord(event.id);
      add(LoadHistoryEvent());
    } catch (e) {
      _handleError(e, emit);
    }
  }

  void _handleError(dynamic error, Emitter<HistoryState> emit) {
    if (error.toString().contains('NETWORK_ERROR')) {
      emit(HistoryErrorState('No se pudo guardar/cargar: revisa tu conexión a internet'));
    } else if (error.toString().contains('AUTH_ERROR')) {
      emit(HistoryErrorState('Sesión expirada, reinicia la app', isAuthError: true));
    } else {
      emit(HistoryErrorState('Ocurrió un error inesperado'));
    }
  }
}
