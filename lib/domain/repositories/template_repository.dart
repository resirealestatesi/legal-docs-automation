import '../entities/template.dart';

abstract class TemplateRepository {
  Future<List<Template>> getTemplatesByCompanyId(String companyId);
  Future<Template?> getTemplateById(String id);
  Future<void> saveTemplate(Template template);
  Future<void> saveTemplates(List<Template> templates);
}
