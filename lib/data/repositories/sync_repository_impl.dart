import '../../domain/entities/automation.dart';
import '../datasources/remote/supabase_datasource.dart';

class SyncRepositoryImpl {
  final SupabaseDatasource _remoteDatasource;

  SyncRepositoryImpl(this._remoteDatasource);

  Future<void> pullFromSupabase(String companyId) async {
    final templatesJson =
        await _remoteDatasource.getTemplatesByCompanyId(companyId);
  }

  Future<void> pushToSupabase() async {
    // Push local changes to Supabase
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
      positionStart: json['position_start'] as int?,
      positionEnd: json['position_end'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
