import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../core/errors/exceptions.dart';

class SupabaseDatasource {
  final SupabaseClient _client;

  SupabaseDatasource(this._client);

  // ==================== COMPANY ====================

  Future<Map<String, dynamic>?> validateCompanyCode(String code) async {
    try {
      final response = await _client
          .from(SupabaseConfig.companiesTable)
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      throw ServerException(message: 'Error validating company code: $e');
    }
  }

  // ==================== TEMPLATES ====================

  Future<List<Map<String, dynamic>>> getTemplatesByCompanyId(
    String companyId,
  ) async {
    try {
      final response = await _client
          .from(SupabaseConfig.templatesTable)
          .select()
          .eq('company_id', companyId)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: 'Error fetching templates: $e');
    }
  }

  Future<Map<String, dynamic>> createTemplate({
    required String companyId,
    required String name,
    String? description,
    String? fileUrl,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConfig.templatesTable)
          .insert({
            'company_id': companyId,
            'name': name,
            'description': description,
            'file_url': fileUrl,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw ServerException(message: 'Error creating template: $e');
    }
  }

  // ==================== AUTOMATIONS ====================

  Future<List<Map<String, dynamic>>> getAutomationsByTemplateIds(
    List<String> templateIds,
  ) async {
    if (templateIds.isEmpty) return [];

    try {
      final response = await _client
          .from(SupabaseConfig.automationsTable)
          .select()
          .inFilter('template_id', templateIds);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: 'Error fetching automations: $e');
    }
  }

  Future<Map<String, dynamic>> createAutomation({
    required String templateId,
    required String fieldName,
    required String highlightText,
    String highlightColor = '#B89B5E4D',
    List<String> fieldOptions = const [],
    int? positionStart,
    int? positionEnd,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConfig.automationsTable)
          .insert({
            'template_id': templateId,
            'field_name': fieldName,
            'highlight_text': highlightText,
            'highlight_color': highlightColor,
            'field_options': fieldOptions,
            'position_start': positionStart,
            'position_end': positionEnd,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw ServerException(message: 'Error creating automation: $e');
    }
  }

  // ==================== SYNC ====================

  Future<List<Map<String, dynamic>>> getAutomationsUpdatedAfter(
    DateTime timestamp,
  ) async {
    try {
      final response = await _client
          .from(SupabaseConfig.automationsTable)
          .select()
          .gte('created_at', timestamp.toIso8601String());

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: 'Error fetching updated automations: $e');
    }
  }
}
