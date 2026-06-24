import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_history_model.dart';

abstract class HistorySupabaseDataSource {
  Future<void> createActivityRecord(ActivityHistoryModel model);
  Future<List<ActivityHistoryModel>> getActivityHistory();
  Future<void> updateActivityRecord(ActivityHistoryModel model);
  Future<void> deleteActivityRecord(String id);
}

class HistorySupabaseDataSourceImpl implements HistorySupabaseDataSource {
  final SupabaseClient _client;

  HistorySupabaseDataSourceImpl({SupabaseClient? client}) 
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> createActivityRecord(ActivityHistoryModel model) async {
    try {
      if (_client.auth.currentUser == null) {
        throw const AuthException('No hay sesión activa', statusCode: '401');
      }

      final data = model.toJson();
      data['user_id'] = _client.auth.currentUser!.id;

      await _client.from('activity_history').insert(data);
    } on SocketException {
      throw Exception('NETWORK_ERROR');
    } on AuthException {
      throw Exception('AUTH_ERROR');
    } catch (e) {
      throw Exception('Error desconocido al guardar la actividad');
    }
  }

  @override
  Future<List<ActivityHistoryModel>> getActivityHistory() async {
    try {
      if (_client.auth.currentUser == null) {
        throw const AuthException('No hay sesión activa', statusCode: '401');
      }

      final response = await _client
          .from('activity_history')
          .select()
          .order('activity_date', ascending: false);

      return (response as List).map((json) => ActivityHistoryModel.fromJson(json)).toList();
    } on SocketException {
      throw Exception('NETWORK_ERROR');
    } on AuthException {
      throw Exception('AUTH_ERROR');
    } catch (e) {
      throw Exception('Error desconocido al obtener el historial');
    }
  }

  @override
  Future<void> updateActivityRecord(ActivityHistoryModel model) async {
    try {
      if (_client.auth.currentUser == null) {
        throw const AuthException('No hay sesión activa', statusCode: '401');
      }

      final data = model.toJson();
      data['user_id'] = _client.auth.currentUser!.id;

      await _client.from('activity_history').update(data).eq('id', model.id!);
    } on SocketException {
      throw Exception('NETWORK_ERROR');
    } on AuthException {
      throw Exception('AUTH_ERROR');
    } catch (e) {
      throw Exception('Error desconocido al actualizar la actividad');
    }
  }

  @override
  Future<void> deleteActivityRecord(String id) async {
    try {
      if (_client.auth.currentUser == null) {
        throw const AuthException('No hay sesión activa', statusCode: '401');
      }

      await _client.from('activity_history').delete().eq('id', id);
    } on SocketException {
      throw Exception('NETWORK_ERROR');
    } on AuthException {
      throw Exception('AUTH_ERROR');
    } catch (e) {
      throw Exception('Error desconocido al eliminar la actividad');
    }
  }
}
