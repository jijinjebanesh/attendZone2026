import 'dart:convert';
import 'package:attendzone_new/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// Import your existing APIs and Models
import '../Api/chatApi.dart';
import '../Api/projectApi.dart';
import '../models/project_model.dart';
import 'chat.dart'; // Assuming this imports the ChatScreen detail view

// Define Theme Colors locally for this file if not global
const Color kOrange = Color(0xFFFF9800);
const Color kOrangeDark = Color(0xFFF57C00);
const Color kOrangeLight = Color(0xFFFFE0B2);
const Color kBackground = Color(0xFFF8F9FA); // Clean off-white background

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late Future<List<Project_model>> _fetchProjectsFuture;
  late List<Map<String, dynamic>> _announcements;
  late PageController _pageController;
  String? _currentUserEmail;
  bool _isLoadingAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _announcements = [];
    _pageController = PageController(viewportFraction: 0.92);
    _refreshData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Refresh both announcements and projects
    _fetchAnnouncements();
    setState(() {
      _fetchProjectsFuture = _fetchProjects();
    });
  }

  Future<void> _fetchAnnouncements() async {
    try {
      List<Map<String, dynamic>> messages = await ChatApi()
          .getPreviousAnnouncements();
      if (mounted) {
        setState(() {
          _announcements = messages;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      print('Failed to fetch announcements: $e');
      if (mounted) {
        setState(() => _isLoadingAnnouncements = false);
      }
    }
  }

  Future<List<Project_model>> _fetchProjects() async {
    final String? fetchedEmail = await GetEmail().getEmail();
    if (mounted) {
      setState(() {
        _currentUserEmail = fetchedEmail;
      });
    }
    // Artificial delay removed for production speed, keep if you want "loading" feel
    // await Future.delayed(const Duration(milliseconds: 300));

    if (fetchedEmail == null) return [];
    return await ProjectApi.getUserProjects(fetchedEmail);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Messages',
            style: GoogleFonts.rubik(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: scheme.onSurfaceVariant, size: 28),
            onPressed: () {
              // Implement search if needed
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        color: kOrange,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // --- Section Header: Announcements ---
              if (_announcements.isNotEmpty || _isLoadingAnnouncements)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.campaign, color: kOrangeDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Announcements",
                        style: GoogleFonts.rubik(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // --- Announcement Slider ---
              _buildAnnouncementSection(scheme),

              const SizedBox(height: 25),

              // --- Section Header: Projects ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Projects",
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // --- Project List ---
              _buildProjectList(scheme),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget: Announcement Section ---
  Widget _buildAnnouncementSection(ColorScheme scheme) {
    if (_isLoadingAnnouncements) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    if (_announcements.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kOrangeLight.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: kOrangeDark,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              "No new announcements",
              style: GoogleFonts.rubik(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _announcements.length,
            itemBuilder: (context, index) {
              final reversedIndex = _announcements.length - 1 - index;
              final item = _announcements[reversedIndex];
              return _buildAnnouncementCard(item);
            },
          ),
        ),
        const SizedBox(height: 15),
        SmoothPageIndicator(
          controller: _pageController,
          count: _announcements.length,
          effect: const ExpandingDotsEffect(
            activeDotColor: kOrange,
            dotColor: Color(0xFFE0E0E0),
            dotHeight: 6,
            dotWidth: 6,
            expansionFactor: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showAnnouncementDialog(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kOrange, kOrangeDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kOrange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background circle
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Update",
                        style: GoogleFonts.rubik(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item['message'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    formatTimeOfDay(item['time']),
                    style: GoogleFonts.rubik(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
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

  // --- Widget: Project List ---
  Widget _buildProjectList(ColorScheme scheme) {
    return FutureBuilder<List<Project_model>>(
      future: _fetchProjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Center(child: CircularProgressIndicator(color: kOrange)),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load projects',
              style: GoogleFonts.rubik(color: scheme.onSurfaceVariant),
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          List<Project_model> projects = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              return _buildProjectTile(projects[index], scheme);
            },
          );
        } else {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 30),
                Icon(Icons.folder_open, size: 50, color: scheme.surfaceVariant),
                const SizedBox(height: 10),
                Text(
                  'No Projects Found',
                  style: GoogleFonts.rubik(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildProjectTile(Project_model project, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: EHelperFunctions.isDarkMode(context) ? Colors.transparent.withAlpha(50) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_currentUserEmail != null) {
              context.push(
                '/Chat',
                extra: ChatScreen(
                  senderEmail: _currentUserEmail!,
                  projectName: project.projectName,
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar
                Container(
                  height: 55,
                  width: 55,
                  decoration: BoxDecoration(
                    color: kOrangeLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    // Using Text initial as backup/primary style if image fails or to look modern
                    child: Text(
                      project.projectName.isNotEmpty
                          ? project.projectName[0].toUpperCase()
                          : "?",
                      style: GoogleFonts.rubik(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kOrangeDark,
                      ),
                    ),
                    // Uncomment below if you strictly want to use the asset image
                    /*
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/images/personImg.png'),
                    ),
                    */
                  ),
                ),
                const SizedBox(width: 15),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Tap to view chat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rubik(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: kOrange),
              const SizedBox(width: 10),
              Text(
                "Announcement",
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            announcement['message'],
            style: GoogleFonts.rubik(color: scheme.onSurface, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: GoogleFonts.rubik(
                  color: kOrangeDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String formatTimeOfDay(String time) {
    try {
      final timeParts = time.split(':');
      final int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final adjustedHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$adjustedHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }
}

class GetEmail {
  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }
}
