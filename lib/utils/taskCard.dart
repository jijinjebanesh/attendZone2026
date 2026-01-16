import '../Api/taskApi.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Api/notionApi.dart';
import '../models/task_model.dart';

class TaskCard extends StatefulWidget {
  final Task_model task;

  const TaskCard({super.key, required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  static const List<String> statusList = [
    'Not Started',
    'In Progress',
    'Completed',
  ];

  late String _currentStatus;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    // Status is already normalized at the model level
    _currentStatus = widget.task.statusName;

    // Safety check: ensure status is in the list
    if (!statusList.contains(_currentStatus)) {
      _currentStatus = statusList.first; // Default to 'Not Started'
      debugPrint(
        'TaskCard WARNING - Status "$_currentStatus" not in statusList, using default: "Not Started"',
      );
    }
    debugPrint('TaskCard initState - Status: "$_currentStatus"');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Color getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.blue;
      case 'Not Started':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);

    try {
      // await updateStatus(widget.task.task_id, newStatus);

      // optimistic UI update
      setState(() {
        _currentStatus = newStatus;
      });
    } catch (e) {
      debugPrint('Failed to update status: $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    } finally {
      setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.task.taskName,
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.task.Description,
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Priority indicator
                  Container(
                    width: 10,
                    height: 10,
                    color: getPriorityColor(widget.task.priority),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.task.priority ?? 'N/A',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const Spacer(),

                  // Status dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(_currentStatus),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _updating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : DropdownButton<String>(
                            value: _currentStatus,
                            underline: const SizedBox(),
                            dropdownColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            iconEnabledColor: Colors.white,
                            onChanged: (String? newValue) {
                              if (newValue != null &&
                                  newValue != _currentStatus) {
                                _updateStatus(newValue);
                              }
                            },
                            items: statusList.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
