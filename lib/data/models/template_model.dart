class TemplateModel {
  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? fileUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TemplateModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.fileUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'description': description,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
