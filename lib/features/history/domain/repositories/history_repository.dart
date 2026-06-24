import '../entities/activity_history.dart';

abstract class HistoryRepository {
  Future<void> createActivityRecord(ActivityHistory activity);
  Future<List<ActivityHistory>> getActivityHistory();
  Future<void> updateActivityRecord(ActivityHistory activity);
  Future<void> deleteActivityRecord(String id);
}
