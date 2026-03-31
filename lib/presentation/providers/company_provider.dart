import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/local/local_datasource.dart';
import '../../data/datasources/remote/supabase_datasource.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../data/repositories/highlight_repository_impl.dart';
import '../../domain/entities/company.dart';

final localDatasourceProvider = Provider<LocalDatasource>((ref) {
  return LocalDatasource();
});

final supabaseDatasourceProvider = Provider<SupabaseDatasource>((ref) {
  final client = Supabase.instance.client;
  return SupabaseDatasource(client);
});

final companyRepositoryProvider = Provider<CompanyRepositoryImpl>((ref) {
  return CompanyRepositoryImpl(
    ref.read(localDatasourceProvider),
    ref.read(supabaseDatasourceProvider),
  );
});

final syncRepositoryProvider = Provider<SyncRepositoryImpl>((ref) {
  return SyncRepositoryImpl(ref.read(supabaseDatasourceProvider));
});

final highlightRepositoryProvider = Provider<HighlightRepositoryImpl>((ref) {
  return HighlightRepositoryImpl(ref.read(localDatasourceProvider));
});

final currentCompanyProvider =
    AsyncNotifierProvider<CompanyNotifier, Company?>(() {
  return CompanyNotifier();
});

class CompanyNotifier extends AsyncNotifier<Company?> {
  @override
  Future<Company?> build() async {
    final repo = ref.read(companyRepositoryProvider);
    return repo.getStoredCompany();
  }

  Future<void> validateAndSave(String code) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(companyRepositoryProvider);
      final company = await repo.validateCompanyCode(code);
      state = AsyncValue.data(company);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void logout() {
    state = const AsyncValue.data(null);
  }
}
