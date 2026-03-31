class Template {
  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? fileUrl;
  final String? localFilePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Template({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.fileUrl,
    this.localFilePath,
    required this.createdAt,
    required this.updatedAt,
  });
}
