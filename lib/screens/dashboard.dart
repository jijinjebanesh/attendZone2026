import 'dart:convert';
import 'package:attendzone_new/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:badges/badges.dart' as badges;
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Import your project files
import '../models/task_model.dart';
import '../utils/taskCard.dart';
import '../api/taskApi.dart';
import '../api/chatApi.dart';
import '../api/Api.dart';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // APIs
  final tasksApi _taskApi = tasksApi();
  final ChatApi _chatApi = ChatApi();
  final Api _userApi = Api();
  final Atten _attenApi = Atten();

  // State Variables
  late Future<List<Task_model>> _fetchTasksFuture;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  // Dynamic Data Containers
  String _firstName = "Loading...";
  String _email = "";
  String _timeIn = "--:--";
  String _timeOut = "--:--";
  double _attendancePercentage = 0.0;
  int _notificationCount = 0;
  String _selectedFilter = 'All'; // Dropdown state
  bool _isCheckedIn = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // 1. Trigger Task Fetch
    setState(() {
      _fetchTasksFuture = _taskApi.fetchTasks();
    });

    // 2. Fetch User Profile & Attendance concurrently
    await Future.wait([
      _fetchUserProfile(),
      _fetchAttendanceStatus(),
      _fetchUnreadChatMessages(),
    ]);
  }

  // --- Data Fetching Methods ---

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedName = prefs.getString('username');
      String? storedEmail = prefs.getString('email');
      print("$storedName is the stored Name");
      // If not in prefs, you might want to fetch from API using _userApi.fetchData(userId)
      // For now, we assume login saved these.
      if (mounted) {
        setState(() {
          _firstName = storedName ?? "User";
          _email = storedEmail ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
  }

  Future<void> _fetchAttendanceStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('email') ?? '';
      String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch from API
      await _attenApi.getAttendance(email, date);

      // Retrieve updated values from Prefs (Atten.getAttendance saves them there)
      String timeIn = prefs.getString('time_in') ?? '';
      String timeOut = prefs.getString('time_out') ?? '';

      // Calculate percentage (Mock logic: if checked in, 50%, if out 100%, or strictly based on hours)
      // For this example, we use a simple logic:
      double percent = 0.0;
      if (timeIn.isNotEmpty) percent = 0.5;
      if (timeOut.isNotEmpty) percent = 1.0;

      if (mounted) {
        setState(() {
          _timeIn = timeIn.isNotEmpty ? timeIn : "--:--";
          _timeOut = timeOut;
          _isCheckedIn = timeIn.isNotEmpty && timeOut.isEmpty;
          _attendancePercentage = percent;
        });
      }
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
    }
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
          print(
            _notificationCount.toString(),
          ); // Debug: print notification count
        }
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<void> _handleCheckInOut() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userid') ?? '';
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String timeNow = DateFormat('HH:mm').format(DateTime.now());

    if (!_isCheckedIn) {
      // Check In
      await _attenApi.updateData(userId, date, timeNow);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Checked In at $timeNow")));
    } else {
      // Check Out
      await _attenApi.updateTimeOut(userId, date, timeNow);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Checked Out at $timeNow")));
    }
    _loadAllData(); // Refresh UI
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- UI Construction ---

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(context),
              const SizedBox(height: 25),
              _buildTaskSectionHeader(context),
              const SizedBox(height: 15),
              _buildTaskCarousel(context),
              const SizedBox(height: 30),
              _buildAttendanceAction(context),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
 // backgroundColor: isDark ? Colors.black : Colors.white,
  elevation: 0,

  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // or same as AppBar color
    statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark, // Android
    statusBarBrightness:
        isDark ? Brightness.dark : Brightness.light, // iOS
  ),

  title: Text(
    'Dashboard',
    style: GoogleFonts.rubik(
      color: isDark ? Colors.white : Colors.black,
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
                Iconsax.message, // Changed to message icon for chat context
                color: Theme.of(context).colorScheme.onSurface,
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome,',
                style: GoogleFonts.rubik(
                  color: EHelperFunctions.isDarkMode(context) ? Colors.grey[300] : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _firstName,
                  style: GoogleFonts.rubik(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _email.length > 25 ? "${_email.substring(0, 22)}..." : _email,
                  style: GoogleFonts.rubik(
                    color: EHelperFunctions.isDarkMode(context)
                        ? Colors.grey[300]
                        : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          CircularPercentIndicator(
            radius: 38.0,
            animation: true,
            animationDuration: 1200,
            lineWidth: 8.0,
            percent: _attendancePercentage,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${(_attendancePercentage * 100).toInt()}%",
                  style: GoogleFonts.rubik(
                    color: EHelperFunctions.isDarkMode(context)
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Goal",
                  style: GoogleFonts.rubik(
                    fontSize: 9,
                    color: EHelperFunctions.isDarkMode(context) ? Colors.grey[300] : Colors.black87,
                  ),
                ),
              ],
            ),
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Colors.grey[100]!,
            progressColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Tasks',
            style: GoogleFonts.rubik(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          // Dropdown for filtering tasks
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey[300]!,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(
                  Iconsax.filter,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                style: GoogleFonts.rubik(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFilter = newValue!;
                  });
                },
                items: <String>['All', 'In Progress', 'Not Started']
                    .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    })
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCarousel(BuildContext context) {
    return SizedBox(
      height: 240,
      child: FutureBuilder<List<Task_model>>(
        future: _fetchTasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return buildShimmerEffect(context);
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading tasks",
                style: GoogleFonts.rubik(color: Colors.red[400]),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context, "No tasks assigned");
          }

          // Filter Logic
          // final tasks = snapshot.data!.where((t) {
          //   if (_selectedFilter == 'All') return true;
          //   return t.statusName == _selectedFilter;
          // }).toList();

          // if (tasks.isEmpty) {
          //   return _buildEmptyState(context, "No $_selectedFilter tasks");
          // }
          final tasks = snapshot.data!
              .where(
                (t) =>
                    t.statusName == 'In Progress' ||
                    t.statusName == 'Not Started',
              )
              .toList();

          if (tasks.isEmpty) {
            return const Center(child: Text("No active tasks"));
          }
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: tasks.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: TaskCard(task: tasks[index]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              SmoothPageIndicator(
                controller: _pageController,
                count: tasks.length,
                effect: WormEffect(
                  activeDotColor: Colors.orange,
                  dotColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade600
                      : Colors.black12,
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.clipboard_text,
            size: 40,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.rubik(
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAction(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isCheckedIn
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _isCheckedIn ? Iconsax.clock : Iconsax.login,
              color: _isCheckedIn ? Colors.orange : Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCheckedIn ? "Checked In" : "Ready to Start?",
                  style: GoogleFonts.rubik(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: EHelperFunctions.isDarkMode(context) ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _isCheckedIn ? "Since $_timeIn" : "Mark your attendance",
                  style: GoogleFonts.rubik(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCheckedIn ? Colors.redAccent : Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            onPressed: _handleCheckInOut,
            child: Text(
              _isCheckedIn ? "Check Out" : "Check In",
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildShimmerEffect(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
      ),
    );
  }
}
