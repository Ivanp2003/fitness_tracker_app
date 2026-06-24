import '../repositories/history_repository.dart';

class DeleteActivityRecord {
  final HistoryRepository repository;

  DeleteActivityRecord(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteActivityRecord(id);
  }
}
