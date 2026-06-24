import '../../domain/entities/activity_history.dart';

abstract class HistoryState {}

class HistoryInitialState extends HistoryState {}

class HistoryLoadingState extends HistoryState {}

class HistoryLoadedState extends HistoryState {
  final List<ActivityHistory> history;
  HistoryLoadedState(this.history);
}

class HistoryErrorState extends HistoryState {
  final String message;
  final bool isAuthError;
  HistoryErrorState(this.message, {this.isAuthError = false});
}
