import 'package:attendzone_new/Api/Api.dart';
import 'package:attendzone_new/api/chatApi.dart'; // Import your ChatApi
import 'package:attendzone_new/models/attendance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<AttendanceEntry> _attendanceData = [];
  bool _isLoading = true;
  late DateTime _selectedDate;
  double totalHours = 0;
  double attendancePercentage = 0;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    await Future.wait([_fetchDataForUser(), _fetchUnreadNotifications()]);
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('email') ?? '';
      if (email.isNotEmpty) {
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
      debugPrint("Notification Error: $e");
    }
  }

  Future<void> _fetchDataForUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('email') ?? '';

      // Using ApiService from your Api.dart
      _attendanceData = await ApiService().fetchAttendanceData(email);

      if (mounted) _calculateTotalHoursAndAttendance();
    } catch (e) {
      debugPrint('Attendance Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateTotalHoursAndAttendance() {
    int selectedMonth = _selectedDate.month;
    int selectedYear = _selectedDate.year;

    List<AttendanceEntry> attendanceForMonth = _attendanceData
        .where(
          (entry) =>
              entry.date.month == selectedMonth &&
              entry.date.year == selectedYear,
        )
        .toList();

    double totalMins = 0;
    for (var entry in attendanceForMonth) {
      // Professional logic: Convert TimeOfDay to minutes since midnight for precision
      int startMins = entry.timeIn.hour * 60 + entry.timeIn.minute;
      int endMins = entry.timeOut.hour * 60 + entry.timeOut.minute;

      if (endMins > startMins) {
        totalMins += (endMins - startMins);
      } else if (entry.timeOut.hour != 0 || entry.timeOut.minute != 0) {
        // Handle overnight shifts if applicable
        totalMins += (1440 - startMins) + endMins;
      }
    }

    int workingDays = _getTotalWorkingDays(selectedMonth, selectedYear);
    int expectedMins = 8 * 60 * workingDays;

    setState(() {
      totalHours = totalMins / 60;
      attendancePercentage = expectedMins > 0
          ? (totalMins / expectedMins).clamp(0.0, 1.0)
          : 0.0;
    });
  }

  int _getTotalWorkingDays(int month, int year) {
    int days = DateTime(year, month + 1, 0).day;
    int workDays = 0;
    for (int i = 1; i <= days; i++) {
      int weekday = DateTime(year, month, i).weekday;
      if (weekday != DateTime.saturday && weekday != DateTime.sunday)
        workDays++;
    }
    return workDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSummaryCard(),
              _buildCalendarSection(),
              _buildHistoryHeader(),
              _buildAttendanceList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Text(
        'Attendance',
        style: GoogleFonts.rubik(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
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
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Summary",
            style: GoogleFonts.rubik(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${totalHours.toStringAsFixed(1)} Hrs",
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(attendancePercentage * 100).toInt()}%",
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LinearPercentIndicator(
            lineHeight: 8.0,
            percent: attendancePercentage,
            backgroundColor: Colors.white24,
            progressColor: Colors.orangeAccent,
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            "Goal: 160 hours / month",
            style: GoogleFonts.rubik(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDarkMode
              ? const ColorScheme.dark(
                  primary: Color(0xFFFFD700), // Orange highlight
                  surface: Color(0xFF2C2C2C),
                )
              : ColorScheme.light(
                  primary: Color(0xFFFF9800), // Orange highlight
                  surface: Colors.white,
                ),
        ),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: DateTime(2021),
          lastDate: DateTime.now(),

          onDateChanged: (date) {
            setState(() => _selectedDate = date);
            _calculateTotalHoursAndAttendance();
          },
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Daily Details",
            style: GoogleFonts.rubik(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: GoogleFonts.rubik(
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_isLoading)
      return Padding(
        padding: const EdgeInsets.all(20),
        child: CircularProgressIndicator(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFD700)
              : const Color(0xFFFF9800),
        ),
      );

    final dailyData = _attendanceData
        .where(
          (e) =>
              e.date.year == _selectedDate.year &&
              e.date.month == _selectedDate.month &&
              e.date.day == _selectedDate.day,
        )
        .toList();

    if (dailyData.isEmpty) {
      bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(30),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[100]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Iconsax.calendar_remove,
              size: 48,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              "No record found for this date",
              style: GoogleFonts.rubik(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: dailyData.map((entry) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.clock,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Work Session",
                      style: GoogleFonts.rubik(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${entry.timeIn.format(context)} - ${entry.timeOut.format(context)}",
                      style: GoogleFonts.rubik(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(isDarkMode ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Present",
                  style: GoogleFonts.rubik(
                    color: Colors.green[isDarkMode ? 300 : 700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
