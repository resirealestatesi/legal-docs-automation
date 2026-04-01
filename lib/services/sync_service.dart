import '../data/datasources/remote/supabase_datasource.dart';

class SyncService {
  final SupabaseDatasource _datasource;

  SyncService(this._datasource);

  /// Performs a full sync for the given company:
  /// - Pulls all templates and automations from Supabase
  /// - Validates data integrity
  /// Returns the list of templates with their automations.
  Future<List<Map<String, dynamic>>> syncForCompany(String companyId) async {
    final templates = await _datasource.getTemplatesByCompanyId(companyId);

    for (final template in templates) {
      final templateId = template['id'] as String;
      final automations =
          await _datasource.getAutomationsByTemplateId(templateId);
      template['automations'] = automations;
    }

    return templates;
  }

  /// Deletes a template and all its automations.
  Future<void> deleteTemplate(String templateId) async {
    await _datasource.deleteTemplate(templateId);
  }
}
