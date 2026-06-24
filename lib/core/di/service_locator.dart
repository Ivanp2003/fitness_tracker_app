import '../../features/history/data/datasources/history_supabase_datasource.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/history/domain/usecases/create_activity_record.dart';
import '../../features/history/domain/usecases/update_activity_record.dart';
import '../../features/history/domain/usecases/delete_activity_record.dart';
import '../../features/history/domain/usecases/get_activity_history.dart';

class ServiceLocator {
  static HistorySupabaseDataSource? _historyDataSource;
  static HistoryRepository? _historyRepository;

  static HistorySupabaseDataSource get historyDataSource {
    _historyDataSource ??= HistorySupabaseDataSourceImpl();
    return _historyDataSource!;
  }

  static HistoryRepository get historyRepository {
    _historyRepository ??= HistoryRepositoryImpl(dataSource: historyDataSource);
    return _historyRepository!;
  }

  static CreateActivityRecord get createActivityRecord => CreateActivityRecord(historyRepository);
  static GetActivityHistory get getActivityHistory => GetActivityHistory(historyRepository);
  static UpdateActivityRecord get updateActivityRecord => UpdateActivityRecord(historyRepository);
  static DeleteActivityRecord get deleteActivityRecord => DeleteActivityRecord(historyRepository);
}
