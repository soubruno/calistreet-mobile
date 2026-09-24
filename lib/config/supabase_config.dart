import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String _defaultUrl = 'https://ixyrxbbeetzoxznebrap.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4eXJ4YmJlZXR6b3h6bmVicmFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwODY4MDksImV4cCI6MjA3NjY2MjgwOX0.-5a2Y10ndzKJ7GFS1kEO158yoMSkmqSbh9aSYtsgf68';

  // Carregar variáveis do .env com fallback seguro para chaves públicas
  static String get url {
    try {
      return dotenv.env['SUPABASE_URL'] ?? _defaultUrl;
    } catch (e) {
      return _defaultUrl;
    }
  }

  static String get anonKey {
    try {
      return dotenv.env['SUPABASE_ANON_KEY'] ?? _defaultAnonKey;
    } catch (e) {
      return _defaultAnonKey;
    }
  }
}