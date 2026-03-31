import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sync_repository_impl.dart';
import 'company_provider.dart';

final syncProvider = Provider<SyncNotifier>((ref) {
  return SyncNotifier(ref.read(syncRepositoryProvider));
});

class SyncNotifier {
  final SyncRepositoryImpl _syncRepository;

  SyncNotifier(this._syncRepository);

  Future<void> syncForCompany(String companyId) async {
    await _syncRepository.pullFromSupabase(companyId);
    await _syncRepository.pushToSupabase();
  }
}
