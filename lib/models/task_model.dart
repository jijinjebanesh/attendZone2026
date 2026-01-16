class Task_model {
  final String taskName;
  final String statusName;
  final String email;
  final String? priority;
  final String Description;
  final String task_id;

  Task_model({
    required this.taskName,
    required this.statusName,
    required this.email,
    required this.Description,
    required this.priority,
    required this.task_id,
  });

  // Normalize status to match dropdown values
  static String _normalizeStatus(String status) {
    if (status.isEmpty) return 'Not Started';

    // Normalize whitespace and trim
    String normalized = status.trim().replaceAll(RegExp(r'\s+'), ' ');

    // First check if it's already a valid status (case-sensitive match)
    const List<String> validStatuses = [
      'Not Started',
      'In Progress',
      'Completed',
    ];
    if (validStatuses.contains(normalized)) {
      return normalized;
    }

    // Convert to lowercase for comparison
    String lower = normalized.toLowerCase();

    // Remove hyphens and underscores for more flexible matching
    String flexible = lower.replaceAll(RegExp(r'[-_]'), ' ');

    // Map various status values to standard values
    if (flexible.contains('complet') ||
        flexible.contains('done') ||
        flexible.contains('finish')) {
      return 'Completed';
    } else if (flexible.contains('progress') ||
        flexible.contains('ongoing') ||
        flexible.contains('doing')) {
      return 'In Progress';
    } else if (flexible.contains('not') && flexible.contains('start') ||
        flexible.contains('pending') ||
        flexible.contains('todo') ||
        flexible.contains('open')) {
      return 'Not Started';
    }

    // Default to 'Not Started' if no match
    return 'Not Started';
  }

  factory Task_model.fromJson(Map<String, dynamic> json) {
    return Task_model(
      taskName: json['taskName'] ?? '',
      statusName: _normalizeStatus(json['statusName'] ?? ''),
      email: json['email'] ?? '',
      priority: json['priority'],
      Description: json['Description'] ?? '',
      task_id: json['task_id'] ?? '',
    );
  }

  // factory Task_model.fromJson(Map<String, dynamic> json) {
  //   String extractTaskName() {
  //     var title = json['properties']['Task name']['title'];
  //     if (title != null && title.isNotEmpty) {
  //       return title[0]['plain_text'] ?? '';
  //     }
  //     return '';
  //   }

  //   String extractStatusName() {
  //     var status = json['properties']['Status'];
  //     if (status != null && status['status'] != null) {
  //       return status['status']['name'] ?? '';
  //     }
  //     return '';
  //   }

  //   String extractTaskId() {
  //     return json['id'] ?? '';
  //   }

  //   String extractDescription() {
  //     var descriptionList = json['properties']['Summary']['rich_text'];
  //     if (descriptionList != null && descriptionList.isNotEmpty) {
  //       var description = descriptionList[0]['plain_text'];
  //       if (description != null && description.isNotEmpty) {
  //         return description;
  //       }
  //     }
  //     return '';
  //   }

  //   String extractAssigneeEmail() {
  //     var assigneeList = json['properties']['Assignee`'];
  //     if (assigneeList != null && assigneeList['people'] != null) {
  //       List<dynamic> emails = assigneeList['people'].map((assignee) {
  //         return assignee['person']['email'] ?? '';
  //       }).toList();
  //       return emails.join(', ');
  //     }
  //     return '';
  //   }

  //   String extractPriority() {
  //     var priority = json['properties']['Priority'];
  //     if (priority != null && priority['select'] != null) {
  //       return priority['select']['name'] ?? 'Not set';
  //     }
  //     return 'Not set';
  //   }

  //   return Task_model(
  //     taskName: extractTaskName(),
  //     statusName: extractStatusName(),
  //     email: extractAssigneeEmail(),
  //     priority: extractPriority(),
  //     Description: extractDescription(),
  //     task_id: extractTaskId(),
  //   );
  // }
}
