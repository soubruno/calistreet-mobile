import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/workout_exercise_item.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';

class WorkoutService {
  final SupabaseClient _serviceClient = AuthService.client;

  static const String _workoutsBoxName = 'workouts_box';
  static const String _userWorkoutsKey = 'user_workouts_list';

  /// Converte recursivamente Map<dynamic, dynamic> do Hive para Map<String, dynamic>
  static Map<String, dynamic> _deepCastMap(Map dynamicMap) {
    final Map<String, dynamic> converted = {};
    dynamicMap.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        converted[stringKey] = _deepCastMap(value);
      } else if (value is List) {
        converted[stringKey] = _deepCastList(value);
      } else {
        converted[stringKey] = value;
      }
    });
    return converted;
  }

  /// Converte recursivamente Listas aninhadas vindas do Hive
  static List<dynamic> _deepCastList(List dynamicList) {
    return dynamicList.map((item) {
      if (item is Map) {
        return _deepCastMap(item);
      } else if (item is List) {
        return _deepCastList(item);
      }
      return item;
    }).toList();
  }

  Future<void> saveNewWorkout({
    required String workoutName,
    required List<WorkoutExerciseItem> items,
    required List<String> scheduleDays,
  }) async {
    final currentUserId = AuthService.currentUser?['user_id'];

    if (currentUserId == null) {
      Logger.warning(
        'WorkoutService',
        'Tentativa de salvar treino sem autenticação',
      );
      throw Exception('Usuário não autenticado. Faça login e tente novamente.');
    }

    if (items.isEmpty) {
      Logger.warning(
        'WorkoutService',
        'Tentativa de salvar treino sem exercícios',
      );
      throw Exception('O treino deve conter pelo menos um exercício.');
    }

    Logger.info(
      'WorkoutService',
      'Salvando novo treino',
      extra: {
        'workout_name': workoutName,
        'user_id': currentUserId,
        'exercises_count': items.length,
        'schedule_days': scheduleDays,
      },
    );

    String? newWorkoutId;

    try {
      // 1. INSERIR NA TABELA 'workouts'
      final List<Map<String, dynamic>> workoutResponse = await _serviceClient
          .from('workouts')
          .insert({
            'name': workoutName,
            'created_by_id': currentUserId,
            'is_template': false,
            'schedule_days': scheduleDays,
          })
          .select('id');

      if (workoutResponse.isEmpty) {
        throw Exception('Falha ao criar registro principal do treino.');
      }

      newWorkoutId = workoutResponse.first['id'] as String;
      Logger.debug(
        'WorkoutService',
        'Treino criado',
        extra: {'workout_id': newWorkoutId},
      );

      // 2. PREPARAR ITENS PARA INSERÇÃO EM LOTE na tabela 'workout_exercises'
      final List<Map<String, dynamic>> itemsToInsert = items
          .asMap()
          .entries
          .map((entry) => entry.value.toJson(newWorkoutId!, entry.key + 1))
          .toList();

      // 3. INSERIR EM LOTE NA TABELA 'workout_exercises'
      await _serviceClient.from('workout_exercises').insert(itemsToInsert);

      // 4. PERSISTIR CÓPIA NO CACHE LOCAL DO HIVE (Para funcionamento offline)
      try {
        final box = await Hive.openBox(_workoutsBoxName);
        final rawList = box.get(_userWorkoutsKey);
        final currentWorkouts = (rawList is List)
            ? rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];

        final newWorkoutMap = {
          'id': newWorkoutId,
          'name': workoutName,
          'created_by_id': currentUserId,
          'schedule_days': scheduleDays,
        };

        // Adiciona o novo treino à lista local geral
        currentWorkouts.add(newWorkoutMap);
        await box.put(_userWorkoutsKey, currentWorkouts);

        // Atualiza também os snapshots dos dias correspondentes
        for (final day in scheduleDays) {
          final dayKey = 'workouts_day_$day';
          final rawDayList = box.get(dayKey);
          final dayWorkouts = (rawDayList is List)
              ? rawDayList.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : <Map<String, dynamic>>[];
          dayWorkouts.add(newWorkoutMap);
          await box.put(dayKey, dayWorkouts);
        }

        // 4.1 Salva o snapshot completo com os exercícios mapeados no padrão esperado
        final cachedWorkoutExercises = items.map((item) {
          return {
            'exercise_id': item.exerciseId,
            'sets': item.sets,
            'repetitions': item.repetitions,
            'exercises': {
              'id': item.exerciseId,
              'name': item.exerciseName,
              'video_url': item.imageUrl,
            }
          };
        }).toList();

        final fullWorkoutDetails = {
          'id': newWorkoutId,
          'name': workoutName,
          'created_by_id': currentUserId,
          'schedule_days': scheduleDays,
          'workout_exercises': cachedWorkoutExercises,
        };

        await box.put('workout_details_$newWorkoutId', fullWorkoutDetails);
        Logger.info('WorkoutService', 'Treino e exercícios detalhados salvos no Hive com sucesso');
      } catch (cacheErr) {
        Logger.warning('WorkoutService', 'Falha secundária ao salvar no Hive', error: cacheErr);
      }

      Logger.info(
        'WorkoutService',
        'Treino salvo com sucesso',
        extra: {'workout_id': newWorkoutId},
      );
    } catch (e, stackTrace) {
      // 5. TRATAMENTO DE ERRO COM REVERSÃO (ROLLBACK) SEGURO
      Logger.error(
        'WorkoutService',
        'Erro ao salvar treino - executando rollback',
        error: e,
        stackTrace: stackTrace,
        extra: {'workout_id': newWorkoutId, 'workout_name': workoutName},
      );

      if (newWorkoutId != null) {
        try {
          await _serviceClient
              .from('workout_exercises')
              .delete()
              .eq('workout_id', newWorkoutId);

          await _serviceClient
              .from('workouts')
              .delete()
              .eq('id', newWorkoutId);

          Logger.info(
            'WorkoutService',
            'Rollback executado com sucesso',
            extra: {'workout_id': newWorkoutId},
          );
        } catch (rollbackError) {
          Logger.error(
            'WorkoutService',
            'Erro ao executar rollback',
            error: rollbackError,
            extra: {'workout_id': newWorkoutId},
          );
        }
      }
      throw Exception(
        ErrorHandler.handleError(
          e,
          stackTrace: stackTrace,
          context: 'saveNewWorkout',
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserWorkouts(String userId) async {
    try {
      Logger.debug(
        'WorkoutService',
        'Buscando treinos do usuário',
        extra: {'user_id': userId},
      );

      final List<dynamic> response = await _serviceClient
          .from('workouts')
          .select('id, name')
          .eq('created_by_id', userId)
          .limit(10);

      final workouts = response.cast<Map<String, dynamic>>();

      // Atualiza cache Hive
      try {
        final box = await Hive.openBox(_workoutsBoxName);
        await box.put(_userWorkoutsKey, workouts);
      } catch (_) {}

      Logger.info(
        'WorkoutService',
        'Treinos carregados com sucesso',
        extra: {'user_id': userId, 'count': workouts.length},
      );
      return workouts;
    } catch (e, stackTrace) {
      Logger.warning(
        'WorkoutService',
        'Erro ao buscar treinos do usuário - tentando cache Hive',
        error: e,
        stackTrace: stackTrace,
        extra: {'user_id': userId},
      );

      // Fallback offline do Hive com tipagem profunda
      try {
        final box = await Hive.openBox(_workoutsBoxName);
        final rawList = box.get(_userWorkoutsKey);
        if (rawList is List) {
          return rawList.map((e) => _deepCastMap(e as Map)).toList();
        }
      } catch (_) {}

      return [];
    }
  }

  // Função para buscar um treino específico pelo ID (com fallback offline seguro via Hive)
  Future<Map<String, dynamic>?> fetchWorkoutById(String workoutId) async {
    final cacheKey = 'workout_details_$workoutId';

    try {
      Logger.debug(
        'WorkoutService',
        'Buscando treino por ID na nuvem',
        extra: {'workout_id': workoutId},
      );

      final response = await _serviceClient
          .from('workouts')
          .select('''
          *,
          workout_exercises(
            *,
            exercises(
              id,
              name,
              description,
              muscle_group,
              subgroup,
              required_equipment,
              video_url,
              level
            )
          )
        ''')
          .eq('id', workoutId)
          .single();

      final data = _deepCastMap(response);

      // Salva snapshot completo no Hive para uso offline futuro
      try {
        final box = await Hive.openBox(_workoutsBoxName);
        await box.put(cacheKey, data);
      } catch (_) {}

      Logger.info(
        'WorkoutService',
        'Treino encontrado com exercícios na nuvem',
        extra: {
          'workout_id': workoutId,
          'exercises_count': (data['workout_exercises'] as List?)?.length ?? 0,
        },
      );
      return data;
    } catch (e, stackTrace) {
      Logger.warning(
        'WorkoutService',
        'Sem conexão para buscar detalhes do treino - recuperando do Hive',
        error: e,
        stackTrace: stackTrace,
        extra: {'workout_id': workoutId},
      );

      // Fallback offline com deep cast garantido
      try {
        final box = await Hive.openBox(_workoutsBoxName);
        final cached = box.get(cacheKey);
        if (cached is Map) {
          return _deepCastMap(cached);
        }
      } catch (_) {}

      return null;
    }
  }

  // Função para atualizar um treino existente
  Future<void> updateWorkout({
    required String workoutId,
    required String workoutName,
    required List<WorkoutExerciseItem> items,
    required List<String> scheduleDays,
  }) async {
    if (items.isEmpty) {
      throw Exception('O treino deve conter pelo menos um exercício.');
    }

    // 1. ATUALIZAR TABELA 'workouts'
    await _serviceClient
        .from('workouts')
        .update({'name': workoutName, 'schedule_days': scheduleDays})
        .eq('id', workoutId);

    // 2. EXCLUIR ITENS ANTIGOS e INSERIR NOVOS
    await _serviceClient
        .from('workout_exercises')
        .delete()
        .eq('workout_id', workoutId);

    // 3. PREPARAR E INSERIR NOVOS ITENS EM LOTE
    final List<Map<String, dynamic>> itemsToInsert = items
        .asMap()
        .entries
        .map((entry) => entry.value.toJson(workoutId, entry.key + 1))
        .toList();

    await _serviceClient.from('workout_exercises').insert(itemsToInsert);

    // 4. ATUALIZAR SNAPSHOT NO HIVE
    try {
      final box = await Hive.openBox(_workoutsBoxName);
      final cachedWorkoutExercises = items.map((item) {
        return {
          'exercise_id': item.exerciseId,
          'sets': item.sets,
          'repetitions': item.repetitions,
          'exercises': {
            'id': item.exerciseId,
            'name': item.exerciseName,
            'video_url': item.imageUrl,
          }
        };
      }).toList();

      final updatedDetails = {
        'id': workoutId,
        'name': workoutName,
        'schedule_days': scheduleDays,
        'workout_exercises': cachedWorkoutExercises,
      };

      await box.put('workout_details_$workoutId', updatedDetails);
    } catch (_) {}
  }

  /// Exclui um treino no Supabase e limpa o registro correspondente no Hive
  Future<void> deleteWorkout(String workoutId) async {
    try {
      Logger.info('WorkoutService', 'Excluindo treino', extra: {'workout_id': workoutId});

      // 1. Exclui os exercícios filhos associados
      await _serviceClient
          .from('workout_exercises')
          .delete()
          .eq('workout_id', workoutId);

      // 2. Exclui o treino principal no Supabase
      await _serviceClient
          .from('workouts')
          .delete()
          .eq('id', workoutId);

      // 3. Remove das caixas do Hive local
      try {
        final box = await Hive.openBox(_workoutsBoxName);

        final rawList = box.get(_userWorkoutsKey);
        if (rawList is List) {
          final updated = rawList
              .where((w) => (w as Map)['id'] != workoutId)
              .map((e) => _deepCastMap(e as Map))
              .toList();
          await box.put(_userWorkoutsKey, updated);
        }

        await box.delete('workout_details_$workoutId');

        const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        for (final day in days) {
          final dayKey = 'workouts_day_$day';
          final rawDayList = box.get(dayKey);
          if (rawDayList is List) {
            final updatedDay = rawDayList
                .where((w) => (w as Map)['id'] != workoutId)
                .map((e) => _deepCastMap(e as Map))
                .toList();
            await box.put(dayKey, updatedDay);
          }
        }

        Logger.info('WorkoutService', 'Treino removido do cache local do Hive');
      } catch (cacheErr) {
        Logger.warning('WorkoutService', 'Falha ao remover do cache local', error: cacheErr);
      }
    } catch (e, stackTrace) {
      Logger.error(
        'WorkoutService',
        'Erro ao excluir treino',
        error: e,
        stackTrace: stackTrace,
        extra: {'workout_id': workoutId},
      );
      throw Exception('Não foi possível excluir o treino.');
    }
  }

  // Função para buscar treinos agendados para um dia específico (com suporte offline via Hive)
  Future<List<Map<String, dynamic>>> fetchUserWorkoutsByDay(
    String userId,
    String currentDay,
  ) async {
    final dayKey = 'workouts_day_$currentDay';

    try {
      Logger.debug(
        'WorkoutService',
        'Buscando treinos por dia',
        extra: {'user_id': userId, 'day': currentDay},
      );

      final List<dynamic> response = await _serviceClient
          .from('workouts')
          .select('id, name, created_by_id, schedule_days')
          .eq('created_by_id', userId)
          .contains('schedule_days', [currentDay])
          .order('id', ascending: false);

      final workouts = response.map((e) => _deepCastMap(e as Map)).toList();

      try {
        final box = await Hive.openBox(_workoutsBoxName);
        await box.put(dayKey, workouts);
      } catch (_) {}

      Logger.info(
        'WorkoutService',
        'Treinos por dia carregados da nuvem',
        extra: {'user_id': userId, 'day': currentDay, 'count': workouts.length},
      );
      return workouts;
    } catch (e, stackTrace) {
      Logger.warning(
        'WorkoutService',
        'Sem conexão ou falha ao buscar treinos - recuperando do cache Hive',
        error: e,
        stackTrace: stackTrace,
        extra: {'user_id': userId, 'day': currentDay},
      );

      try {
        final box = await Hive.openBox(_workoutsBoxName);
        
        final cachedDay = box.get(dayKey);
        if (cachedDay is List && cachedDay.isNotEmpty) {
          return cachedDay.map((e) => _deepCastMap(e as Map)).toList();
        }

        final allCached = box.get(_userWorkoutsKey);
        if (allCached is List) {
          return allCached
              .map((e) => _deepCastMap(e as Map))
              .where((w) {
                final days = (w['schedule_days'] as List?)?.cast<String>() ?? [];
                return days.contains(currentDay);
              })
              .toList();
        }
      } catch (_) {}

      return [];
    }
  }
}