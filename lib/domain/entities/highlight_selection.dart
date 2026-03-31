class HighlightSelection {
  final int? id;
  final String templateId;
  final String fieldName;
  final String highlightText;
  final int startOffset;
  final int endOffset;
  final String colorHex;
  final double opacity;
  final List<String> options;
  final DateTime createdAt;

  const HighlightSelection({
    this.id,
    required this.templateId,
    required this.fieldName,
    required this.highlightText,
    required this.startOffset,
    required this.endOffset,
    this.colorHex = '#B89B5E',
    this.opacity = 0.3,
    this.options = const [],
    required this.createdAt,
  });

  HighlightSelection copyWith({
    int? id,
    String? templateId,
    String? fieldName,
    String? highlightText,
    int? startOffset,
    int? endOffset,
    String? colorHex,
    double? opacity,
    List<String>? options,
    DateTime? createdAt,
  }) {
    return HighlightSelection(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      fieldName: fieldName ?? this.fieldName,
      highlightText: highlightText ?? this.highlightText,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      colorHex: colorHex ?? this.colorHex,
      opacity: opacity ?? this.opacity,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
