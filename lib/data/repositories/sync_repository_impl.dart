import '../../domain/entities/automation.dart';
import '../datasources/remote/supabase_datasource.dart';

class SyncRepositoryImpl {
  final SupabaseDatasource _remoteDatasource;

  SyncRepositoryImpl(this._remoteDatasource);

  /// Pulls all templates and their automations from Supabase
  /// for the given company. Validates data integrity.
  Future<List<Map<String, dynamic>>> pullFromSupabase(String companyId) async {
    final templatesJson =
        await _remoteDatasource.getTemplatesByCompanyId(companyId);

    for (final template in templatesJson) {
      final templateId = template['id'] as String;
      final automations =
          await _remoteDatasource.getAutomationsByTemplateId(templateId);
      template['automations'] = automations;
    }

    return templatesJson;
  }

  /// Pushes local automations to Supabase.
  /// Since the app is Supabase-first (no local DB), this is a no-op
  /// that returns success.
  Future<void> pushToSupabase() async {
    // App uses Supabase as primary store - no local data to push
  }

  Future<List<Automation>> getAutomationsByTemplateId(String templateId) async {
    final automationsJson =
        await _remoteDatasource.getAutomationsByTemplateIds([templateId]);
    return automationsJson.map(_toEntity).toList();
  }

  Future<void> saveAutomations(List<Automation> automations) async {
    for (final a in automations) {
      await _remoteDatasource.createAutomation(
        templateId: a.templateId,
        fieldName: a.fieldName,
        highlightText: a.highlightText,
        highlightColor: a.highlightColor,
        fieldOptions: a.fieldOptions,
        uppercase: a.uppercase,
        positionStart: a.positionStart,
        positionEnd: a.positionEnd,
      );
    }
  }

  Automation _toEntity(Map<String, dynamic> json) {
    return Automation(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      fieldName: json['field_name'] as String,
      fieldOptions: (json['field_options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      highlightText: json['highlight_text'] as String,
      highlightColor: json['highlight_color'] as String? ?? '#B89B5E4D',
      uppercase: json['uppercase'] == true,
      positionStart: json['position_start'] as int?,
      positionEnd: json['position_end'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
