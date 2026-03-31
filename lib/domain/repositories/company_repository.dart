import '../entities/company.dart';

abstract class CompanyRepository {
  Future<Company> validateCompanyCode(String code);
  Future<Company?> getStoredCompany();
  Future<void> saveCompany(Company company);
}
