class Project {
  final int id;
  final String name;
  final String? description;
  final String? status;
  final String? startDate;
  final String? endDate;
  final int createdBy;
  final String? createdAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.status,
    this.startDate,
    this.endDate,
    required this.createdBy,
    this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? 'Untitled Project',
      description: json['description'],
      status: json['status'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      createdBy: json['created_by'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}
