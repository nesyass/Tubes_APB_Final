class SupabaseStorageConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const bucket = String.fromEnvironment('SUPABASE_STORAGE_BUCKET',
      defaultValue: 'order-files');

  static String get key => publishableKey.isNotEmpty ? publishableKey : anonKey;

  static bool get isConfigured => url.isNotEmpty && key.isNotEmpty;
}
