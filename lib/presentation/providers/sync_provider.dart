import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sync_repository_impl.dart';
import 'company_provider.dart';

final syncProvider = Provider<SyncNotifier>((ref) {
  return SyncNotifier(ref.read(syncRepositoryProvider));
});

class SyncNotifier {
  final SyncRepositoryImpl _syncRepository;

  SyncNotifier(this._syncRepository);

  /// Syncs all templates and automations for a company.
  /// Returns the list of templates with their automations.
  Future<List<Map<String, dynamic>>> syncForCompany(String companyId) async {
    final templates = await _syncRepository.pullFromSupabase(companyId);
    await _syncRepository.pushToSupabase();
    return templates;
  }
}
