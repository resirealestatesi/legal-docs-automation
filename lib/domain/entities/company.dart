class Company {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const Company({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });
}
