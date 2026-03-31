class Automation {
  final String id;
  final String templateId;
  final String fieldName;
  final List<String> fieldOptions;
  final String highlightText;
  final String highlightColor;
  final int? positionStart;
  final int? positionEnd;
  final DateTime createdAt;

  const Automation({
    required this.id,
    required this.templateId,
    required this.fieldName,
    required this.fieldOptions,
    required this.highlightText,
    required this.highlightColor,
    this.positionStart,
    this.positionEnd,
    required this.createdAt,
  });
}
