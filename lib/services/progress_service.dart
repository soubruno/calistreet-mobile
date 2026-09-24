import 'dart:convert';
import 'package:calistreet/models/progress.dart';
import 'package:calistreet/services/auth_service.dart';
import 'package:calistreet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/achievement.dart';

class ProgressService {
  final SupabaseClient _client = AuthService.client;
  final Uuid _uuid = const Uuid();

  static const String _progressBoxName = 'progress_box';
  static const String _cachedLast7DaysKey = 'cached_last_7_days_progress';
  static const String _cachedHistoryKey = 'cached_workout_history';
  static const String _activeOfflineSessionKey = 'active_offline_session';
  static const String _pendingSyncKey = 'pending_sync_sessions';

  static Map<String, dynamic> _deepCastMap(Map dynamicMap) {
    final Map<String, dynamic> converted = {};
    dynamicMap.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        converted[stringKey] = _deepCastMap(value);
      } else if (value is List) {
        converted[stringKey] = value.map((e) => e is Map ? _deepCastMap(e) : e).toList();
      } else {
        converted[stringKey] = value;
      }
    });
    return converted;
  }

  int _parseReps(dynamic rpc) {
    if (rpc == null) return 0;
    if (rpc is num) return rpc.toInt();
    if (rpc is Map && rpc['total'] != null) {
      final total = rpc['total'];
      return (total is num) ? total.toInt() : (int.tryParse(total.toString()) ?? 0);
    }
    if (rpc is List && rpc.isNotEmpty) {
      final first = rpc.first;
      if (first is Map && first['total'] != null) {
        final total = first['total'];
        return (total is num) ? total.toInt() : (int.tryParse(total.toString()) ?? 0);
      }
      if (first is num) return first.toInt();
    }
    return int.tryParse(rpc.toString()) ?? 0;
  }

  Future<void> syncPendingSessions() async {
    try {
      final box = await Hive.openBox(_progressBoxName);
      final rawPending = box.get(_pendingSyncKey) as List?;

      if (rawPending == null || rawPending.isEmpty) return;

      Logger.info('ProgressService', 'Sincronizando ${rawPending.length} treinos pendentes...');

      final List<Map<String, dynamic>> remaining = [];

      for (final item in rawPending) {
        final session = _deepCastMap(item as Map);
        final String progressId = session['id'] ?? '';
        final String userId = session['user_id'] ?? '';
        final String workoutId = session['workout_id'] ?? '';

        try {
          await _client.from('progress').upsert({
            'id': progressId.startsWith('offline_') ? _uuid.v4() : progressId,
            'user_id': userId,
            'workout_id': workoutId.isNotEmpty ? workoutId : null,
            'start_date': session['start_date'],
            'end_date': session['end_date'],
            'duration_seconds': session['duration_seconds'],
            'status': 'COMPLETED',
            if (session['notes'] != null) 'notes': session['notes'],
          });
        } catch (syncErr) {
          Logger.warning('ProgressService', 'Falha ao sincronizar item, mantendo na fila', error: syncErr);
          remaining.add(session);
        }
      }

      await box.put(_pendingSyncKey, remaining);
      Logger.info('ProgressService', 'Sincronização concluída. Restantes: ${remaining.length}');
    } catch (e) {
      Logger.warning('ProgressService', 'Erro no processo geral de sincronização', error: e);
    }
  }

  Future<List<Progress>> getProgressForUser(String userId) async {
    try {
      final response = await _client
          .from('progress')
          .select('*')
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      final List<Progress> progressList = (response as List)
          .map((data) => Progress.fromJson(data as Map<String, dynamic>))
          .toList();
      return progressList;
    } catch (e) {
      Logger.error('ProgressService', 'Erro ao buscar progresso do usuário', error: e);
      rethrow;
    }
  }

  Future<void> addProgress(Progress progress) async {
    try {
      await _client.from('progress').insert(progress.toJson());
    } catch (e) {
      Logger.error('ProgressService', 'Erro ao adicionar progresso', error: e);
      rethrow;
    }
  }

  Future<List<Progress>> getLast7DaysProgress(String userId) async {
    await syncPendingSessions();

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final response = await _client
          .from('progress')
          .select('*')
          .eq('user_id', userId)
          .gte('start_date', sevenDaysAgo.toIso8601String())
          .order('start_date', ascending: true);

      final List<Progress> cloudProgress = (response as List)
          .map((data) => Progress.fromJson(data as Map<String, dynamic>))
          .toList();

      final box = await Hive.openBox(_progressBoxName);
      final rawPending = box.get(_pendingSyncKey) as List? ?? [];
      final pendingProgress = rawPending.map((p) => Progress.fromJson(_deepCastMap(p as Map))).toList();

      final mergedList = [...cloudProgress, ...pendingProgress];

      try {
        final rawMapList = mergedList.map((data) => data.toJson()).toList();
        await box.put(_cachedLast7DaysKey, rawMapList);
      } catch (cacheErr) {
        Logger.warning('ProgressService', 'Falha ao salvar cache de 7 dias', error: cacheErr);
      }

      return mergedList;
    } catch (e) {
      Logger.warning('ProgressService', 'Sem conexão - usando fallback Hive', error: e);

      try {
        final box = await Hive.openBox(_progressBoxName);
        final cached = box.get(_cachedLast7DaysKey) as List?;
        if (cached != null) {
          return cached.map((data) {
            final map = _deepCastMap(data as Map);
            return Progress.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      return [];
    }
  }

  Future<List<Progress>> getCurrentWeekProgress(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      final response = await _client
          .from('progress')
          .select('*')
          .eq('user_id', userId)
          .gte('start_date', startOfWeek.toIso8601String())
          .lte('start_date', endOfWeek.toIso8601String())
          .order('start_date', ascending: true);

      final List<Progress> progressList = (response as List)
          .map((data) => Progress.fromJson(data as Map<String, dynamic>))
          .toList();
      return progressList;
    } catch (e) {
      Logger.error('ProgressService', 'Erro ao buscar progresso da semana atual', error: e);
      return [];
    }
  }

  Future<String> startWorkoutProgress({
    required String userId,
    required String workoutId,
  }) async {
    final sessionId = _uuid.v4();
    final startDate = DateTime.now().toIso8601String();

    try {
      await _client.from('progress').insert({
        'id': sessionId,
        'user_id': userId,
        'workout_id': workoutId,
        'start_date': startDate,
        'status': 'IN_PROGRESS',
      });

      try {
        final box = await Hive.openBox(_progressBoxName);
        await box.put(_activeOfflineSessionKey, {
          'id': sessionId,
          'user_id': userId,
          'workout_id': workoutId,
          'start_date': startDate,
          'is_offline': false,
        });
      } catch (_) {}

      return sessionId;
    } catch (e) {
      Logger.warning('ProgressService', 'Falha de rede - fallback para sessão offline', error: e);

      final box = await Hive.openBox(_progressBoxName);
      await box.put(_activeOfflineSessionKey, {
        'id': sessionId,
        'user_id': userId,
        'workout_id': workoutId,
        'start_date': startDate,
        'is_offline': true,
      });

      return sessionId;
    }
  }

  Future<void> completeWorkoutProgress({
    required String progressId,
    required int durationSeconds,
    String? notes,
    List<Map<String, dynamic>>? exerciseTimestamps,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final userId = AuthService.currentUser?['user_id'] ?? '';

    String workoutId = '';
    String workoutName = 'Treino Concluído';
    DateTime startDate = now.subtract(Duration(seconds: durationSeconds));

    try {
      final box = await Hive.openBox(_progressBoxName);
      final sessionData = box.get(_activeOfflineSessionKey) as Map?;
      if (sessionData != null) {
        workoutId = sessionData['workout_id']?.toString() ?? '';
        if (sessionData['start_date'] != null) {
          startDate = DateTime.tryParse(sessionData['start_date']) ?? startDate;
        }
      }

      if (workoutId.isNotEmpty) {
        final workoutBox = await Hive.openBox('workouts_box');
        final workoutDetails = workoutBox.get('workout_details_$workoutId') as Map?;
        if (workoutDetails != null) {
          workoutName = workoutDetails['name']?.toString() ?? workoutName;
        }
      }
    } catch (_) {}

    final completedMap = {
      'id': progressId,
      'user_id': userId,
      'workout_id': workoutId,
      'workout_name': workoutName,
      'workouts': {'name': workoutName},
      'start_date': startDate.toIso8601String(),
      'end_date': nowIso,
      'duration_seconds': durationSeconds,
      'status': 'COMPLETED',
      'notes': notes,
      'exercises_breakdown': exerciseTimestamps ?? [],
    };

    try {
      final box = await Hive.openBox(_progressBoxName);

      final rawHistory = box.get(_cachedHistoryKey) as List? ?? [];
      final updatedHistory = [
        completedMap,
        ...rawHistory.map((e) => _deepCastMap(e as Map)),
      ];
      await box.put(_cachedHistoryKey, updatedHistory);

      final raw7Days = box.get(_cachedLast7DaysKey) as List? ?? [];
      final updated7Days = [
        ...raw7Days.map((e) => _deepCastMap(e as Map)),
        completedMap,
      ];
      await box.put(_cachedLast7DaysKey, updated7Days);

      await box.delete(_activeOfflineSessionKey);

      final pendingQueue = box.get(_pendingSyncKey) as List? ?? [];
      await box.put(_pendingSyncKey, [...pendingQueue, completedMap]);

      Logger.info('ProgressService', 'Treino gravado no histórico local com sucesso');
    } catch (cacheErr) {
      Logger.warning('ProgressService', 'Erro ao persistir sessão offline', error: cacheErr);
    }

    try {
      if (progressId.startsWith('offline_')) {
        await _client.from('progress').insert({
          'id': progressId,
          'user_id': userId,
          'workout_id': workoutId,
          'start_date': startDate.toIso8601String(),
          'end_date': nowIso,
          'duration_seconds': durationSeconds,
          'status': 'COMPLETED',
          if (notes != null) 'notes': notes,
        });
      } else {
        await _client.from('progress').update({
          'end_date': nowIso,
          'duration_seconds': durationSeconds,
          'status': 'COMPLETED',
          if (notes != null) 'notes': notes,
        }).eq('id', progressId);
      }
    } catch (e) {
      Logger.warning('ProgressService', 'Sem conexão: sessão gravada no Hive e enfileirada.');
    }
  }

  Future<void> cancelWorkoutProgress({
    required String progressId,
    String? notes,
  }) async {
    try {
      await _client.from('progress').update({
        'end_date': DateTime.now().toIso8601String(),
        'status': 'SKIPPED',
        if (notes != null) 'notes': notes,
      }).eq('id', progressId);

      final box = await Hive.openBox(_progressBoxName);
      await box.delete(_activeOfflineSessionKey);

      Logger.info('ProgressService', 'Progresso cancelado');
    } catch (e) {
      Logger.warning('ProgressService', 'Erro ao cancelar progresso no Supabase', error: e);
    }
  }

  Future<int> countCompletedWorkouts(String userId) async {
    try {
      final response = await _client
          .from('progress')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'COMPLETED');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> fetchTotalDuration(String userId) async {
    final List<Progress> allProgress = await getAllUserProgress(userId);
    int totalSeconds = allProgress
        .where((p) => p.status == ProgressStatus.completed && p.durationSeconds != null)
        .fold(0, (sum, p) => sum + p.durationSeconds!);
    return totalSeconds;
  }

  Future<List<Map<String, dynamic>>> getWorkoutHistory(String userId) async {
    await syncPendingSessions();

    try {
      final List<dynamic> response = await _client
          .from('progress')
          .select('*, workouts(name)')
          .eq('user_id', userId)
          .order('start_date', ascending: false)
          .limit(20);

      final cloudHistory = response.map((data) {
        final workoutName =
            (data['workouts'] as Map<String, dynamic>?)?['name'] ?? 'Treino Excluído';

        return {
          'id': data['id'],
          'workout_name': workoutName,
          'workouts': {'name': workoutName},
          'date': DateTime.parse(data['start_date'] as String),
          'duration': data['duration_seconds'],
          'status': data['status'],
          'exercises_breakdown': data['exercises_breakdown'] ?? [],
        };
      }).toList();

      final box = await Hive.openBox(_progressBoxName);
      final rawPending = box.get(_pendingSyncKey) as List? ?? [];
      final pendingHistory = rawPending.map((e) {
        final m = _deepCastMap(e as Map);
        final name = m['workout_name'] ?? 'Treino Concluído';
        return {
          'id': m['id'],
          'workout_name': name,
          'workouts': {'name': name},
          'date': DateTime.tryParse(m['start_date'] ?? '') ?? DateTime.now(),
          'duration': m['duration_seconds'] ?? 0,
          'status': m['status'] ?? 'COMPLETED',
          'exercises_breakdown': m['exercises_breakdown'] ?? [],
        };
      }).toList();

      final mergedHistory = [...pendingHistory, ...cloudHistory];
      mergedHistory.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      try {
        await box.put(
          _cachedHistoryKey,
          mergedHistory.map((e) => {...e, 'date': (e['date'] as DateTime).toIso8601String()}).toList(),
        );
      } catch (_) {}

      return mergedHistory;
    } catch (e) {
      Logger.warning('ProgressService', 'Offline: buscando histórico do cache Hive');

      try {
        final box = await Hive.openBox(_progressBoxName);
        final cached = box.get(_cachedHistoryKey) as List?;
        if (cached != null) {
          return cached.map((e) {
            final m = _deepCastMap(e as Map);
            final name = m['workout_name'] ?? (m['workouts'] as Map?)?['name'] ?? 'Treino';
            return {
              ...m,
              'workout_name': name,
              'workouts': {'name': name},
              'date': DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
              'duration': m['duration'] ?? m['duration_seconds'] ?? 0,
              'status': m['status'] ?? 'COMPLETED',
              'exercises_breakdown': m['exercises_breakdown'] ?? [],
            };
          }).toList();
        }
      } catch (_) {}

      return [];
    }
  }

  Future<List<String>> checkAchievements(String userId) async {
    try {
      final achievementsResponse = await _client.from('achievements').select('*');
      final unlockedIds = <String>[];

      for (final json in achievementsResponse) {
        final achievement = Achievement.fromJson(json, isUnlocked: false);

        final rpc = await _client.rpc('sum_user_reps', params: {
          'user_id_param': userId,
          'exercise_id_param': achievement.targetExerciseId,
        });

        final int totalReps = _parseReps(rpc);

        if (totalReps >= achievement.thresholdCount) {
          final alreadyUnlocked = await _client
              .from('user_achievements')
              .select()
              .eq('user_id', userId)
              .eq('achievement_id', achievement.id)
              .maybeSingle();

          if (alreadyUnlocked == null) {
            await _client.from('user_achievements').insert({
              'user_id': userId,
              'achievement_id': achievement.id,
            });
          }

          unlockedIds.add(achievement.id);
        }
      }

      return unlockedIds;
    } catch (e) {
      Logger.warning('ProgressService', 'Erro ao verificar conquistas', error: e);
      return [];
    }
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final achievementRows = await _client.from('achievements').select('*');

      final unlockedRows = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      final unlockedIds = unlockedRows.map((e) => e['achievement_id']).toSet();

      final futures = achievementRows.map((json) async {
        final achId = json['id'] as String;
        final exerciseId = json['target_exercise_id'] as String?;

        int totalReps = 0;
        if (exerciseId != null) {
          try {
            final rpc = await _client.rpc(
              'sum_user_reps',
              params: {
                'user_id_param': userId,
                'exercise_id_param': exerciseId,
              },
            );
            totalReps = _parseReps(rpc);
          } catch (e) {
            totalReps = 0;
          }
        }

        return Achievement.fromJson(
          json,
          isUnlocked: unlockedIds.contains(achId) ||
              totalReps >= (json['threshold_count'] as int? ?? 0),
        ).copyWith(
          currentValue: totalReps,
          targetValue: json['threshold_count'] as int? ?? 0,
        );
      });

      return await Future.wait(futures);
    } catch (e) {
      Logger.warning('ProgressService', 'Erro ao buscar conquistas - retornando vazias', error: e);
      return [];
    }
  }

  Future<List<Progress>> getAllUserProgress(String userId) async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('progress').select().eq('user_id', userId);

      return data.map((json) => Progress.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}