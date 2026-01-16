import 'package:attendzone_new/Api/projectApi.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart'; // Ensure this is added to pubspec.yaml
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;

import '../helper_functions.dart';
import '../models/project_model.dart';
import '../api/chatApi.dart';
import 'project_details.dart'; // Import the Details page we made earlier

class Projects extends StatefulWidget {
  const Projects({super.key});

  @override
  State<Projects> createState() => _ProjectsState();
}
  
class _ProjectsState extends State<Projects> with AutomaticKeepAliveClientMixin {
  late Future<List<Project_model>> _fetchProjectsFuture;
  int _notificationCount = 0;
  String? email;

  @override
  void initState() {
    super.initState();
    _fetchProjectsFuture = fetchProjects();
    _fetchUnreadChatMessages();
  }
   @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    super.dispose();
  }

  Future<List<Project_model>> fetchProjects() async {
    final String? fetchedEmail = await GetEmail().getEmail();
    if (mounted) {
      setState(() {
        email = fetchedEmail;
      });
    }

    // Simulate slight delay for smooth UI transition if needed, or remove
    await Future.delayed(const Duration(milliseconds: 500));

    if (fetchedEmail == null) return [];

    return await ProjectApi.getUserProjects(fetchedEmail);
  }

  Future<void> _fetchUnreadChatMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('email') ?? '';
      if (email.isNotEmpty) {
        // Fetch real messages
        final messages = await ChatApi.getChatMessages(email);

        if (mounted) {
          setState(() {
            _notificationCount = messages.where((m) {
              // Handle both model objects and raw maps
              final readBy = m is Map
                  ? (m['readBy'] as List? ?? [])
                  : (m.readBy ?? []);

              // Check if email is in readBy list (handles both String list and Map list)
              final isRead = readBy.any((r) {
                if (r is Map) {
                  return r['reader'] == email;
                } else if (r is String) {
                  return r == email;
                }
                return false;
              });

              return !isRead;
            }).length;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'My Projects',
          style: GoogleFonts.rubik(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: () => context.push('/announcements'),
              icon: badges.Badge(
                showBadge: _notificationCount > 0,
                badgeContent: Text(
                  '$_notificationCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                child: Icon(
                  Iconsax.message,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _fetchProjectsFuture = fetchProjects();
          });
          await _fetchUnreadChatMessages();
        },
        child: FutureBuilder<List<Project_model>>(
          future: _fetchProjectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList(context);
            } else if (snapshot.hasError) {
              return _buildErrorState(context, snapshot.error.toString());
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(context);
            } else {
              final projects = snapshot.data!;
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: projects.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildProjectCard(context, projects[index]);
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, Project_model project) {
    final theme = Theme.of(context);
    final completionColor = _getPriorityColor(project.priority);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailsPage(
              projectName: project.projectName,
              statusName: project.statusName,
              link: project.link ?? "",
              completionPercentage: project.completionPercentage,
              priority: project.priority,
              startDate: project.startDate,
              endDate: project.endDate,
              tasks: project.tasks,
              assignees: project.assignees,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Priority
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    project.projectName,
                    style: GoogleFonts.rubik(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildPriorityBadge(project.priority),
              ],
            ),
            const SizedBox(height: 12),

            // Middle: Assignees and Date
            Row(
              children: [
                if (project.assignees.isNotEmpty) ...[
                  _buildAssigneeStack(context, project.assignees),
                  const SizedBox(width: 12),
                ],
                Icon(
                  Iconsax.calendar_1,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  project.endDate != null
                      ? DateFormat('MMM d').format(project.endDate!)
                      : 'No Date',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bottom: Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(project.completionPercentage * 100).toInt()}%',
                      style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.completionPercentage.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: completionColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String? priority) {
    Color color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        (priority ?? 'Normal').toUpperCase(),
        style: GoogleFonts.rubik(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAssigneeStack(BuildContext context, List<String> assignees) {
    // Show max 3 avatars
    final displayList = assignees.take(3).toList();
    final remaining = assignees.length - 3;

    return SizedBox(
      height: 28,
      width: 20.0 * displayList.length + (remaining > 0 ? 20 : 0),
      child: Stack(
        children: [
          for (int i = 0; i < displayList.length; i++)
            Positioned(
              left: i * 18.0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      Colors.primaries[i % Colors.primaries.length].shade200,
                  child: Text(
                    displayList[i].isNotEmpty
                        ? displayList[i][0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.rubik(
                      fontSize: 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayList.length * 18.0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: Text(
                    '+$remaining',
                    style: GoogleFonts.rubik(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.folder_open,
            size: 60,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            "No Projects Found",
            style: GoogleFonts.rubik(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              "Something went wrong",
              style: GoogleFonts.rubik(fontWeight: FontWeight.bold),
            ),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(fontSize: 12, color: Colors.grey),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _fetchProjectsFuture = fetchProjects();
                });
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red.shade500;
      case 'medium':
        return Colors.orange.shade500;
      case 'low':
        return Colors.green.shade500;
      default:
        return Colors.blue.shade500;
    }
  }
}

// Simple Helper Class if not already defined in your project
class GetEmail {
  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }
}
