class Project_model {
  final String projectName;
  final String statusName;
  final double completionPercentage;
  final String? priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> tasks;
  final String? icon;
  final List<String> assignees;
  final String? link;

  Project_model({
    required this.projectName,
    required this.statusName,
    required this.completionPercentage,
    this.priority,
    this.startDate,
    this.endDate,
    required this.assignees,
    required this.tasks,
    this.icon,
    this.link,
  });

  /// For lightweight project lists (dashboard / sidebar)
  factory Project_model.fromSimpleJson(Map<String, dynamic> json) {
    return Project_model(
      projectName: json['projectName'] ?? '',
      statusName: json['statusName'] ?? '',
      completionPercentage:
          (json['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      priority: json['priority'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      tasks: List<String>.from(json['tasks'] ?? []),
      assignees: List<String>.from(json['assignees'] ?? []),
      icon: json['icon'],
      link: json['link'],
    );
  }

  /// For full project details (optional but recommended)
  factory Project_model.fromJson(Map<String, dynamic> json) {
    return Project_model(
      projectName: json['projectName'],
      statusName: json['statusName'],
      completionPercentage: (json['completionPercentage'] as num).toDouble(),
      priority: json['priority'],
      startDate: DateTime.tryParse(json['startDate'] ?? ''),
      endDate: DateTime.tryParse(json['endDate'] ?? ''),
      tasks: List<String>.from(json['tasks']),
      assignees: List<String>.from(json['assignees']),
      icon: json['icon'],
      link: json['link'],
    );
  }
}
