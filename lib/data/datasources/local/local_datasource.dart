import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatasource {
  static const _companyCodeKey = 'company_code';
  static const _companyNameKey = 'company_name';
  static const _companyIdKey = 'company_id';
  static const _highlightsKey = 'highlights';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ==================== COMPANY ====================

  Future<String?> getStoredCompanyCode() async {
    final prefs = await _prefs;
    return prefs.getString(_companyCodeKey);
  }

  Future<String?> getStoredCompanyId() async {
    final prefs = await _prefs;
    return prefs.getString(_companyIdKey);
  }

  Future<String?> getStoredCompanyName() async {
    final prefs = await _prefs;
    return prefs.getString(_companyNameKey);
  }

  Future<void> saveCompany({
    required String id,
    required String code,
    required String name,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_companyIdKey, id);
    await prefs.setString(_companyCodeKey, code);
    await prefs.setString(_companyNameKey, name);
  }

  Future<void> clearCompany() async {
    final prefs = await _prefs;
    await prefs.remove(_companyIdKey);
    await prefs.remove(_companyCodeKey);
    await prefs.remove(_companyNameKey);
  }

  // ==================== HIGHLIGHTS ====================

  Future<List<Map<String, dynamic>>> getHighlights(String templateId) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString('${_highlightsKey}_$templateId');
    if (jsonStr == null) return [];

    final list = jsonDecode(jsonStr) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> saveHighlights(
      String templateId, List<Map<String, dynamic>> highlights) async {
    final prefs = await _prefs;
    await prefs.setString(
        '${_highlightsKey}_$templateId', jsonEncode(highlights));
  }

  Future<void> clearHighlights(String templateId) async {
    final prefs = await _prefs;
    await prefs.remove('${_highlightsKey}_$templateId');
  }
}
