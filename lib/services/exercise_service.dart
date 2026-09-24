import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class ExerciseService {
  final SupabaseClient _publicClient = AuthService.client;

  static const String _boxName = 'exercises_box';
  static const String _cacheKey = 'cached_exercises_raw';
  static const String _timestampKey = 'cached_exercises_timestamp';

  // Tempo de validade do cache local: 24 horas
  static const Duration _cacheTtl = Duration(hours: 24);

  /// Busca todos os exercícios com suporte a Cache Local (Hive).
  ///
  /// - Se houver cache válido no disco, retorna instantaneamente (0ms).
  /// - Se o cache expirou ou não existe, busca no Supabase e atualiza o disco.
  /// - [forceRefresh]: se for true, ignora o cache local e busca direto do Supabase.
  Future<List<Exercise>> fetchAllExercises({bool forceRefresh = false}) async {
    try {
      final box = await Hive.openBox(_boxName);

      final cachedTimestamp = box.get(_timestampKey) as int?;
      final cachedRaw = box.get(_cacheKey);

      final isExpired = cachedTimestamp == null ||
          DateTime.now().millisecondsSinceEpoch - cachedTimestamp >
              _cacheTtl.inMilliseconds;

      // 1. Tenta entregar do cache local se ainda for recente
      if (!forceRefresh && !isExpired && cachedRaw != null) {
        Logger.info('ExerciseService', 'Carregando exercícios direto do cache Hive (0ms)');
        return _parseExercises(cachedRaw);
      }

      // 2. Busca no Supabase
      Logger.debug('ExerciseService', 'Buscando exercícios no Supabase...');
      final List<dynamic> response = await _publicClient
          .from('exercises')
          .select('*')
          .order('name', ascending: true);

      final List<Map<String, dynamic>> rawList =
          response.map((data) => Map<String, dynamic>.from(data as Map)).toList();

      // 3. Salva no Hive para as próximas leituras
      await box.put(_cacheKey, rawList);
      await box.put(_timestampKey, DateTime.now().millisecondsSinceEpoch);

      final exercises = rawList.map((data) => Exercise.fromJson(data)).toList();

      Logger.info(
        'ExerciseService',
        'Exercícios carregados do Supabase e salvos no Hive com sucesso',
        extra: {'count': exercises.length},
      );

      return exercises;
    } catch (e, stackTrace) {
      Logger.error(
        'ExerciseService',
        'Erro ao buscar exercícios - tentando fallback do cache',
        error: e,
        stackTrace: stackTrace,
      );

      // Fallback offline: se a requisição falhou, tenta entregar o que tiver no cache (mesmo antigo)
      try {
        final box = await Hive.openBox(_boxName);
        final cachedRaw = box.get(_cacheKey);
        if (cachedRaw != null) {
          Logger.warning('ExerciseService', 'Utilizando cache local como fallback');
          return _parseExercises(cachedRaw);
        }
      } catch (_) {}

      return [];
    }
  }

  /// Converte a lista crua armazenada no Hive para List<Exercise>
  List<Exercise> _parseExercises(dynamic rawList) {
    if (rawList is List) {
      return rawList.map((item) {
        return Exercise.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    }
    return [];
  }

  /// Limpa o cache de exercícios manualmente se necessário
  Future<void> clearCache() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
    Logger.info('ExerciseService', 'Cache de exercícios limpo');
  }
}