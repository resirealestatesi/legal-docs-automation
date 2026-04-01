class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String companiesTable = 'companies';
  static const String templatesTable = 'templates';
  static const String automationsTable = 'automations';

  static const String templatesBucket = 'templates-docx';
}
