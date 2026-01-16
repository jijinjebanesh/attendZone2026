import 'dart:convert';
import 'dart:typed_data';

import 'package:attendzone_new/Api/Api.dart';
import 'package:attendzone_new/api/taskApi.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with AutomaticKeepAliveClientMixin {
  String? email;
  String? userName;
  String? userId;

  /// Raw bytes (optional)
  Uint8List? _profileBytes;

  /// 🔥 Cached ImageProvider (IMPORTANT)
  ImageProvider? _profileImageProvider;

  int completedTasks = 0;
  double attendanceRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
   @override
  bool get wantKeepAlive => true;
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final base64String = prefs.getString('profile');
    ImageProvider? imageProvider;

    if (base64String != null && base64String.isNotEmpty) {
      final bytes = base64Decode(base64String);
      _profileBytes = bytes;
      imageProvider = MemoryImage(bytes); // ✅ cache once
    }

    setState(() {
      email = prefs.getString('email') ?? 'No Email';
      userName = prefs.getString('username') ?? 'User';
      userId = prefs.getString('userid') ?? 'N/A';
      _profileImageProvider = imageProvider;
    });

    _fetchDynamicStats();
  }

  Future<void> _fetchDynamicStats() async {
    final tasks = await tasksApi().fetchTasks();
    final history = await ApiService().fetchAttendanceData(email ?? "");

    if (!mounted) return;

    setState(() {
      completedTasks = tasks.where((e) => e.statusName == 'Completed').length;

      attendanceRate = history.isEmpty
          ? 0
          : (history.length / 22).clamp(0.0, 1.0);
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStatsRow(),
                const SizedBox(height: 25),
                _buildInfoSection(),
                const SizedBox(height: 20),
                _buildActionSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── APP BAR ─────────────────

  Widget _buildSliverAppBar() {
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: scheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildProfileImage(),
                const SizedBox(height: 12),
                Text(
                  userName ?? "",
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Senior Developer",
                  style: GoogleFonts.rubik(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
          ),
          child: RepaintBoundary(
            child: CircleAvatar(
              radius: 55,
              backgroundColor: scheme.surfaceVariant,
              backgroundImage: _profileImageProvider,
              child: _profileImageProvider == null
                  ? Icon(Iconsax.user, size: 40, color: scheme.primary)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2),
            ),
            child: Icon(Iconsax.camera, size: 16, color: scheme.onSecondary),
          ),
        ),
      ],
    );
  }

  // ───────────────── STATS ─────────────────

  Widget _buildStatsRow() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      transform: Matrix4.translationValues(0, -30, 0),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            "Tasks Done",
            completedTasks.toString(),
            Iconsax.tick_circle,
          ),
          Container(
            width: 1,
            height: 40,
            color: scheme.outline.withOpacity(0.2),
          ),
          _statItem(
            "Attendance",
            "${(attendanceRate * 100).toInt()}%",
            Iconsax.calendar_tick,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.rubik(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.rubik(
            fontSize: 12,
            color: scheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ───────────────── INFO ─────────────────

  Widget _buildInfoSection() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personal Information",
            style: GoogleFonts.rubik(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _infoTile(Iconsax.sms, "Email Address", email ?? ""),
          _infoTile(Iconsax.personalcard, "Employee ID", userId ?? ""),
          _infoTile(Iconsax.briefcase, "Department", "Engineering"),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.rubik(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────── ACTIONS ─────────────────

  Widget _buildActionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _actionTile(Iconsax.setting_2, "Account Settings"),
          _actionTile(Iconsax.info_circle, "Help & Support"),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: Icon(MdiIcons.logout, color: Colors.red),
              label: Text(
                "Logout Account",
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.12),
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: scheme.onSurface),
      title: Text(title, style: GoogleFonts.rubik(color: scheme.onSurface)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: scheme.outline),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out of AttendZone?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
