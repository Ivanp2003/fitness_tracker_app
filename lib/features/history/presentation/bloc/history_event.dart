import '../../domain/entities/activity_history.dart';

abstract class HistoryEvent {}

class LoadHistoryEvent extends HistoryEvent {}

class AddActivityEvent extends HistoryEvent {
  final ActivityHistory activity;
  AddActivityEvent(this.activity);
}

class UpdateActivityEvent extends HistoryEvent {
  final ActivityHistory activity;
  UpdateActivityEvent(this.activity);
}

class DeleteActivityEvent extends HistoryEvent {
  final String id;
  DeleteActivityEvent(this.id);
}
