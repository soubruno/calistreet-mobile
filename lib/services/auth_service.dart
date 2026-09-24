import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/supabase_config.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';

class AuthService {
  static SupabaseClient? _supabase;

  static const String _userBoxName = 'user_box';
  static const String _userProfileKey = 'current_user_profile';

  static SupabaseClient get client {
    _supabase ??= Supabase.instance.client;
    return _supabase!;
  }

  static Future<void> initialize() async {
    try {
      Logger.info('AuthService', 'Inicializando Supabase...');
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      Logger.info('AuthService', 'Supabase inicializado com sucesso');
    } catch (e, stackTrace) {
      Logger.error(
        'AuthService',
        'Falha ao inicializar Supabase',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      Logger.info(
        'AuthService',
        'Iniciando cadastro de usuário',
        extra: {'email': email},
      );

      final AuthResponse response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );

      final User? user = response.user;

      if (user != null) {
        Logger.info(
          'AuthService',
          'Usuário cadastrado com sucesso',
          extra: {'user_id': user.id},
        );

        final userData = {
          'success': true,
          'user_id': user.id,
          'email': user.email,
          'name': name.trim(),
          'created_at': user.createdAt,
          'message': 'Conta criada com sucesso!',
        };

        setCurrentUser(userData);
        return userData;
      } else {
        throw Exception('Falha ao criar conta - resposta vazia do servidor');
      }
    } catch (e, stackTrace) {
      Logger.error(
        'AuthService',
        'Erro ao criar conta',
        error: e,
        stackTrace: stackTrace,
        extra: {'email': email},
      );
      throw Exception(
        ErrorHandler.handleError(e, stackTrace: stackTrace, context: 'signUp'),
      );
    }
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('AuthService', 'Iniciando login', extra: {'email': email});

      final AuthResponse response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = response.user;

      if (user != null) {
        Logger.info(
          'AuthService',
          'Login realizado com sucesso',
          extra: {'user_id': user.id},
        );

        final String? userName = user.userMetadata?['name'] as String?;

        final userData = {
          'success': true,
          'user_id': user.id,
          'email': user.email,
          'name': userName ?? user.email?.split('@')[0] ?? 'Usuário',
          'created_at': user.createdAt,
          'message': 'Login realizado com sucesso!',
        };

        setCurrentUser(userData);
        return userData;
      } else {
        Logger.warning(
          'AuthService',
          'Credenciais inválidas',
          extra: {'email': email},
        );
        throw Exception('Email ou senha incorretos');
      }
    } catch (e, stackTrace) {
      Logger.error(
        'AuthService',
        'Erro ao fazer login',
        error: e,
        stackTrace: stackTrace,
        extra: {'email': email},
      );
      throw Exception(
        ErrorHandler.handleError(e, stackTrace: stackTrace, context: 'signIn'),
      );
    }
  }

  static Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      Logger.debug(
        'AuthService',
        'Buscando perfil do usuário',
        extra: {'user_id': userId},
      );

      final profileData = await client
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileData != null) {
        Logger.info(
          'AuthService',
          'Perfil encontrado com sucesso',
          extra: {'user_id': userId},
        );

        // Se encontrou nome no perfil, enriquece o cache local
        if (profileData['name'] != null && _currentUser != null) {
          _currentUser!['name'] = profileData['name'];
          saveUserLocally(_currentUser!);
        }
      }

      return profileData;
    } catch (e, stackTrace) {
      Logger.warning(
        'AuthService',
        'Perfil não encontrado ou erro ao buscar',
        error: e,
        stackTrace: stackTrace,
        extra: {'user_id': userId},
      );
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e, stackTrace) {
      Logger.error(
        'AuthService',
        'Erro ao encerrar sessão no Supabase',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      clearCurrentUser();
    }
  }

  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser {
    if (_currentUser != null) return _currentUser;

    // 1. Tenta obter da sessão ativa em memória do Supabase
    final currentSession = client.auth.currentSession;
    if (currentSession != null) {
      final user = currentSession.user;
      final String? metaName = user.userMetadata?['name'] as String?;
      _currentUser = {
        'user_id': user.id,
        'email': user.email,
        'name': metaName ?? user.email?.split('@')[0] ?? 'Usuário',
      };

      // Persiste no Hive em segundo plano
      saveUserLocally(_currentUser!);
      return _currentUser;
    }

    // 2. Fallback offline: se estiver sem rede e a sessão não foi revalidada, lê do Hive
    try {
      if (Hive.isBoxOpen(_userBoxName)) {
        final box = Hive.box(_userBoxName);
        final cached = box.get(_userProfileKey);
        if (cached != null) {
          _currentUser = Map<String, dynamic>.from(cached as Map);
          return _currentUser;
        }
      }
    } catch (_) {}

    return _currentUser;
  }

  /// Salva os dados do usuário no Hive para acesso instantâneo e offline
  static Future<void> saveUserLocally(Map<String, dynamic> userData) async {
    try {
      final box = await Hive.openBox(_userBoxName);
      await box.put(_userProfileKey, userData);
    } catch (e) {
      Logger.warning('AuthService', 'Erro ao salvar usuário no Hive', error: e);
    }
  }

  static Future<bool> isUserAuthenticated() async => client.auth.currentSession != null;

  static Future<Map<String, dynamic>?> getCurrentUserData() async => currentUser;

  static void setCurrentUser(Map<String, dynamic> user) {
    _currentUser = user;
    saveUserLocally(user);
  }

  static void clearCurrentUser() async {
    _currentUser = null;
    try {
      final box = await Hive.openBox(_userBoxName);
      await box.clear();
    } catch (_) {}
  }
}