import '../entities/activity_history.dart';
import '../repositories/history_repository.dart';

class GetActivityHistory {
  final HistoryRepository repository;

  GetActivityHistory(this.repository);

  Future<List<ActivityHistory>> call() async {
    return await repository.getActivityHistory();
  }
}
