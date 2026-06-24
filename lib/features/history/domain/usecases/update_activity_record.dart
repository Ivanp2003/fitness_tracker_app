import '../entities/activity_history.dart';
import '../repositories/history_repository.dart';

class UpdateActivityRecord {
  final HistoryRepository repository;

  UpdateActivityRecord(this.repository);

  Future<void> call(ActivityHistory activity) async {
    return await repository.updateActivityRecord(activity);
  }
}
