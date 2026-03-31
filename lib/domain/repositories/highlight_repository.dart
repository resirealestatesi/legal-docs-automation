import '../entities/highlight_selection.dart';

abstract class HighlightRepository {
  Future<List<HighlightSelection>> getHighlightsByTemplateId(String templateId);
  Future<int> saveHighlight(HighlightSelection highlight);
  Future<void> deleteHighlight(int id);
  Future<void> clearHighlightsByTemplateId(String templateId);
}
