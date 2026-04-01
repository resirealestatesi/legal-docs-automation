import 'dart:typed_data';
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

  Future<void> updateTemplate({
    required String id,
    required String name,
    String? description,
    String? fileUrl,
  }) async {
    try {
      final updates = {
        'name': name,
        'description': description,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fileUrl != null) updates['file_url'] = fileUrl;

      await _client.from(SupabaseConfig.templatesTable).update(updates).eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error updating template: $e');
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _client
          .from(SupabaseConfig.automationsTable)
          .delete()
          .eq('template_id', id);

      await _client.from(SupabaseConfig.templatesTable).delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error deleting template: $e');
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

  Future<List<Map<String, dynamic>>> getAutomationsByTemplateId(
    String templateId,
  ) async {
    try {
      final response = await _client
          .from(SupabaseConfig.automationsTable)
          .select()
          .eq('template_id', templateId)
          .order('created_at');

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
    bool uppercase = false,
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
            'uppercase': uppercase,
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

  Future<void> updateAutomation({
    required String id,
    required String fieldName,
    required String highlightText,
    List<String> fieldOptions = const [],
  }) async {
    try {
      await _client.from(SupabaseConfig.automationsTable).update({
        'field_name': fieldName,
        'highlight_text': highlightText,
        'field_options': fieldOptions,
      }).eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error updating automation: $e');
    }
  }

  Future<void> deleteAutomation(String id) async {
    try {
      await _client.from(SupabaseConfig.automationsTable).delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error deleting automation: $e');
    }
  }

  Future<void> deleteAutomationsByTemplateId(String templateId) async {
    try {
      await _client
          .from(SupabaseConfig.automationsTable)
          .delete()
          .eq('template_id', templateId);
    } catch (e) {
      throw ServerException(message: 'Error deleting automations: $e');
    }
  }

  // ==================== TEMPLATE VALUES ====================

  Future<void> saveTemplateValues(
    List<Map<String, String>> values,
  ) async {
    try {
      for (final v in values) {
        await _client.from('template_values').upsert({
          'automation_id': v['automation_id'],
          'filled_value': v['value'],
        });
      }
    } catch (e) {
      throw ServerException(message: 'Error saving template values: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTemplateValues(
    String automationId,
  ) async {
    try {
      final response = await _client
          .from('template_values')
          .select()
          .eq('automation_id', automationId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: 'Error fetching template values: $e');
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
      throw ServerException(
        message: 'Error fetching updated automations: $e',
      );
    }
  }

  // ==================== STORAGE ====================

  /// Uploads a .docx file to Supabase Storage and returns the public path.
  Future<String> uploadDocxFile({
    required String templateId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final storagePath = '$templateId/$fileName';
      await _client.storage.from(SupabaseConfig.templatesBucket).uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(
              contentType:
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              upsert: true,
            ),
          );
      return storagePath;
    } catch (e) {
      throw ServerException(message: 'Error uploading .docx file: $e');
    }
  }

  /// Downloads a .docx file from Supabase Storage and returns its bytes.
  Future<Uint8List> downloadDocxFile(String storagePath) async {
    try {
      final bytes = await _client.storage
          .from(SupabaseConfig.templatesBucket)
          .download(storagePath);
      return bytes;
    } catch (e) {
      throw ServerException(message: 'Error downloading .docx file: $e');
    }
  }

  /// Deletes the .docx file from Supabase Storage.
  Future<void> deleteDocxFile(String storagePath) async {
    try {
      await _client.storage
          .from(SupabaseConfig.templatesBucket)
          .remove([storagePath]);
    } catch (e) {
      throw ServerException(message: 'Error deleting .docx file: $e');
    }
  }
}
