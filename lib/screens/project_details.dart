import 'package:attendzone_new/utils/appbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailsPage extends StatelessWidget {
  final String projectName;
  final String statusName;
  final double completionPercentage;
  final String link;
  final String? priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> tasks;
  final List<String> assignees;

  const ProjectDetailsPage({
    super.key,
    required this.projectName,
    required this.statusName,
    required this.completionPercentage,
    required this.link,
    this.priority,
    this.startDate,
    this.endDate,
    required this.tasks,
    required this.assignees,
  });

  @override
  Widget build(BuildContext context) {
    // Access theme colors for consistency
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Clean background
      appBar: AppBar(
        title: Text(
          'Project Overview',
          style: GoogleFonts.rubik(
            color: Theme.of(  context).colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Header Section (Title & Priority) ---
            _buildHeaderSection(context),
            const SizedBox(height: 24),

            // --- 2. Progress Indicator ---
            _buildProgressSection(context),
            const SizedBox(height: 24),

            // --- 3. Timeline Grid ---
            _buildInfoGrid(context),
            const SizedBox(height: 24),

            // --- 4. Team Section ---
            if (assignees.isNotEmpty) ...[
              Text(
                "Team Members",
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTeamSection(context),
              const SizedBox(height: 24),
            ],

            // --- 5. Tasks List ---
            if (tasks.isNotEmpty) ...[
              Text(
                "Key Deliverables",
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTasksList(context),
            ],

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),

      // Floating Action Button for Repository Link
      floatingActionButton: link.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final Uri url = Uri.parse(link);
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not launch $link')),
                  );
                }
              },
              backgroundColor: const Color(0xFF24292e), // GitHub Black
              icon: const FaIcon(FontAwesomeIcons.github, color: Colors.white),
              label: Text(
                "View Repository",
                style: GoogleFonts.rubik(color: Colors.white),
              ),
            )
          : null,
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                projectName,
                style: GoogleFonts.rubik(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildStatusBadge(statusName),
          ],
        ),
        const SizedBox(height: 12),
        if (priority != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getPriorityColor(priority!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _getPriorityColor(priority!), width: 1),
            ),
            child: Text(
              "$priority Priority".toUpperCase(),
              style: GoogleFonts.rubik(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getPriorityColor(priority!),
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Completion Status",
                style: GoogleFonts.rubik(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Text(
                "${(completionPercentage * 100).toInt()}%",
                style: GoogleFonts.rubik(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completionPercentage,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: _getStatusColor(statusName),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.calendar_today_outlined,
            label: "Start Date",
            value: _formatDate(startDate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.flag_outlined,
            label: "Due Date",
            value: _formatDate(endDate),
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: colorScheme.outline.withOpacity(0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: isHighlighted ? colorScheme.primary : colorScheme.secondary,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.rubik(
              color: colorScheme.primary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rubik(
              color: colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: assignees.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Chip(
            avatar: CircleAvatar(
              backgroundColor:
                  Colors.primaries[index % Colors.primaries.length].shade200,
              child: Text(
                assignees[index].isNotEmpty
                    ? assignees[index][0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            label: Text(
              assignees[index],
              style: GoogleFonts.rubik(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksList(BuildContext context) {
    return Column(
      children: tasks
          .map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    Icons.check_circle_outline_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  title: Text(
                    task,
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // --- HELPER METHODS ---

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: GoogleFonts.rubik(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'delayed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'TBD';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
