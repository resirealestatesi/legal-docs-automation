import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/template.dart';
import 'company_provider.dart';

final templatesProvider =
    FutureProvider.family<List<Template>, String>((ref, companyId) async {
  final repo = ref.read(syncRepositoryProvider);
  final automations = await repo.getAutomationsByTemplateId(companyId);
  return [];
});
