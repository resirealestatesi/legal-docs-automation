import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/remote/supabase_datasource.dart';
import '../../config/supabase_config.dart';

final templatesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from(SupabaseConfig.templatesTable)
      .select()
      .eq('company_id', companyId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final automationsByTemplateProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, templateId) async {
  final supabase = Supabase.instance.client;
  final datasource = SupabaseDatasource(supabase);
  return datasource.getAutomationsByTemplateId(templateId);
});
