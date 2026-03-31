class AutomationModel {
  final String id;
  final String templateId;
  final String fieldName;
  final List<String> fieldOptions;
  final String highlightText;
  final String highlightColor;
  final int? positionStart;
  final int? positionEnd;
  final DateTime createdAt;

  const AutomationModel({
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

  factory AutomationModel.fromJson(Map<String, dynamic> json) {
    return AutomationModel(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      fieldName: json['field_name'] as String,
      fieldOptions:
          (json['field_options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      highlightText: json['highlight_text'] as String,
      highlightColor: json['highlight_color'] as String? ?? '#B89B5E4D',
      positionStart: json['position_start'] as int?,
      positionEnd: json['position_end'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'field_name': fieldName,
      'field_options': fieldOptions,
      'highlight_text': highlightText,
      'highlight_color': highlightColor,
      'position_start': positionStart,
      'position_end': positionEnd,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
