import '../../domain/entities/company.dart';
import '../datasources/local/local_datasource.dart';
import '../datasources/remote/supabase_datasource.dart';
import '../../core/errors/exceptions.dart';

class CompanyRepositoryImpl {
  final LocalDatasource _localDatasource;
  final SupabaseDatasource _remoteDatasource;

  CompanyRepositoryImpl(this._localDatasource, this._remoteDatasource);

  Future<Company> validateCompanyCode(String code) async {
    final response = await _remoteDatasource.validateCompanyCode(code);

    if (response == null) {
      throw const ValidationException(
        message: 'Código de empresa no válido o inactivo',
      );
    }

    await _localDatasource.saveCompany(
      id: response['id'] as String,
      code: response['code'] as String,
      name: response['name'] as String,
    );

    return Company(
      id: response['id'] as String,
      code: response['code'] as String,
      name: response['name'] as String,
      isActive: response['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(response['created_at'] as String),
    );
  }

  Future<Company?> getStoredCompany() async {
    final id = await _localDatasource.getStoredCompanyId();
    final code = await _localDatasource.getStoredCompanyCode();
    final name = await _localDatasource.getStoredCompanyName();

    if (id == null || code == null || name == null) return null;

    return Company(
      id: id,
      code: code,
      name: name,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  Future<void> saveCompany(Company company) async {
    await _localDatasource.saveCompany(
      id: company.id,
      code: company.code,
      name: company.name,
    );
  }
}
