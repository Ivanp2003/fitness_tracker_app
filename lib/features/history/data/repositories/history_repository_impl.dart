import '../../domain/entities/activity_history.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/history_supabase_datasource.dart';
import '../models/activity_history_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final HistorySupabaseDataSource _dataSource;

  HistoryRepositoryImpl({required HistorySupabaseDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<void> createActivityRecord(ActivityHistory activity) async {
    final model = ActivityHistoryModel(
      activityDate: activity.activityDate,
      durationSeconds: activity.durationSeconds,
      primaryActivityType: activity.primaryActivityType,
      totalSteps: activity.totalSteps,
      estimatedCalories: activity.estimatedCalories,
      fallDetected: activity.fallDetected,
    );
    await _dataSource.createActivityRecord(model);
  }

  @override
  Future<List<ActivityHistory>> getActivityHistory() async {
    return await _dataSource.getActivityHistory();
  }

  @override
  Future<void> updateActivityRecord(ActivityHistory activity) async {
    final model = ActivityHistoryModel(
      id: activity.id,
      activityDate: activity.activityDate,
      durationSeconds: activity.durationSeconds,
      primaryActivityType: activity.primaryActivityType,
      totalSteps: activity.totalSteps,
      estimatedCalories: activity.estimatedCalories,
      fallDetected: activity.fallDetected,
    );
    await _dataSource.updateActivityRecord(model);
  }

  @override
  Future<void> deleteActivityRecord(String id) async {
    await _dataSource.deleteActivityRecord(id);
  }
}
