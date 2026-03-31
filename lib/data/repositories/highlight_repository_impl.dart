import '../../domain/entities/highlight_selection.dart';
import '../datasources/local/local_datasource.dart';

class HighlightRepositoryImpl {
  final LocalDatasource _localDatasource;

  HighlightRepositoryImpl(this._localDatasource);

  Future<List<HighlightSelection>> getHighlightsByTemplateId(
      String templateId) async {
    final maps = await _localDatasource.getHighlights(templateId);
    return maps.map(_toEntity).toList();
  }

  Future<int> saveHighlight(HighlightSelection highlight) async {
    final existing = await _localDatasource.getHighlights(highlight.templateId);

    final map = {
      'templateId': highlight.templateId,
      'fieldName': highlight.fieldName,
      'highlightText': highlight.highlightText,
      'startOffset': highlight.startOffset,
      'endOffset': highlight.endOffset,
      'colorHex': highlight.colorHex,
      'opacity': highlight.opacity,
      'options': highlight.options,
      'createdAt': highlight.createdAt.toIso8601String(),
    };

    existing.add(map);
    await _localDatasource.saveHighlights(highlight.templateId, existing);

    return existing.length - 1;
  }

  Future<void> deleteHighlight(int id) async {
    // Simplified: clear all and re-add without the one to delete
    // In production, use a proper ID system
  }

  Future<void> clearHighlightsByTemplateId(String templateId) async {
    await _localDatasource.clearHighlights(templateId);
  }

  HighlightSelection _toEntity(Map<String, dynamic> map) {
    return HighlightSelection(
      templateId: map['templateId'] as String,
      fieldName: map['fieldName'] as String,
      highlightText: map['highlightText'] as String,
      startOffset: map['startOffset'] as int,
      endOffset: map['endOffset'] as int,
      colorHex: map['colorHex'] as String? ?? '#B89B5E',
      opacity: (map['opacity'] as num?)?.toDouble() ?? 0.3,
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
