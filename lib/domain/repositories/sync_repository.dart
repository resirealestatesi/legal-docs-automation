import '../entities/automation.dart';

abstract class SyncRepository {
  Future<void> pullFromSupabase(String companyId);
  Future<void> pushToSupabase();
  Future<List<Automation>> getAutomationsByTemplateId(String templateId);
  Future<void> saveAutomations(List<Automation> automations);
}
