import '../entities/activity_history.dart';
import '../repositories/history_repository.dart';

class CreateActivityRecord {
  final HistoryRepository repository;

  CreateActivityRecord(this.repository);

  Future<void> call(ActivityHistory activity) async {
    return await repository.createActivityRecord(activity);
  }
}
