import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vteachsync/auth/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:vteachsync/screens/profile_screen.dart';
import 'package:vteachsync/screens/explore_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;
  String? userRole;
  String? userName;
  bool isLoading = true;

  // Lists to store data
  List<Map<String, dynamic>> _teacherLocations = [];
  List<Map<String, dynamic>> _classrooms = [];
  List<Map<String, dynamic>> _timetables = [];
  List<Map<String, dynamic>> _teachers = [];

  // Selected day for timetable
  String _selectedDay =
      DateFormat('EEEE').format(DateTime.now()); // Current day
  String _currentTime = DateFormat('HH:mm').format(DateTime.now());

  // Timer for refreshing the time
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTeacherLocations();
    _loadClassrooms();
    _loadTeachers();
    _loadTimetables();

    // Set up timer to update current time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('HH:mm').format(DateTime.now());
        });
        // Refresh data when time changes
        _loadTeacherLocations();
        _loadClassrooms();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userRole =
                (userDoc.data() as Map<String, dynamic>)['role'] ?? 'Student';
            userName =
                (userDoc.data() as Map<String, dynamic>)['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadTeacherLocations() async {
    try {
      // First, get all teachers
      QuerySnapshot teacherSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Teacher')
          .get();

      List<Map<String, dynamic>> teachers = [];

      // Then get timetables for current day
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('day', isEqualTo: _selectedDay)
          .get();

      // Map to store teacher's current location
      Map<String, String> teacherLocations = {};
      Map<String, bool> teacherHasClass = {};

      // Process timetables to determine teacher locations
      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['startTime'] as String;
        final endTime = data['endTime'] as String;
        final teacherId = data['teacherId'] as String;
        final classroomId = data['classroomId'] as String;

        // Mark this teacher as having classes today
        teacherHasClass[teacherId] = true;

        // Check if this timeslot is current
        if (_isCurrentlyInTimeSlot(startTime, endTime)) {
          // Get classroom details
          DocumentSnapshot classroomDoc = await FirebaseFirestore.instance
              .collection('classrooms')
              .doc(classroomId)
              .get();

          if (classroomDoc.exists) {
            final classroomData = classroomDoc.data() as Map<String, dynamic>;
            teacherLocations[teacherId] =
                classroomData['name'] ?? 'Unknown room';
          }
        }
      }

      // Process teacher data with locations
      for (var doc in teacherSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final teacherId = doc.id;

        // Set location to "Faculty Room" if teacher has no class at this time
        String location = teacherLocations[teacherId] ?? 'Faculty Room';

        teachers.add({
          'id': teacherId,
          'name': data['name'] ?? 'Unknown Teacher',
          'subject': data['subject'] ?? 'Not specified',
          'currentLocation': location,
          'hasClasses': teacherHasClass[teacherId] ?? false,
          'lastUpdated': Timestamp.now(),
        });
      }

      setState(() {
        _teacherLocations = teachers;
      });
    } catch (e) {
      print('Error loading teacher locations: $e');
    }
  }

  bool _isCurrentlyInTimeSlot(String startTime, String endTime) {
    try {
      final format = DateFormat('HH:mm');
      final now = format.parse(_currentTime);
      final start = format.parse(startTime);
      final end = format.parse(endTime);

      return now.isAfter(start) && now.isBefore(end);
    } catch (e) {
      print('Error parsing time: $e');
      return false;
    }
  }

  Future<void> _loadClassrooms() async {
    try {
      QuerySnapshot classroomSnapshot =
          await FirebaseFirestore.instance.collection('classrooms').get();

      List<Map<String, dynamic>> classrooms = [];

      for (var doc in classroomSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if classroom is currently occupied
        String status = await _getClassroomCurrentStatus(doc.id);
        String currentSubject = await _getClassroomCurrentSubject(doc.id);

        classrooms.add({
          'id': doc.id,
          'roomNumber': data['name'] ?? 'Unknown',
          'building': data['building'] ?? 'Unknown',
          'floor': data['floor'] ?? 'Unknown',
          'capacity': data['capacity'] ?? 0,
          'facilities': data['facilities'] ?? 'None',
          'status': status,
          'subject': currentSubject,
          'lastUpdated': Timestamp.now(),
        });
      }

      setState(() {
        _classrooms = classrooms;
      });
    } catch (e) {
      print('Error loading classrooms: $e');
    }
  }

  Future<String> _getClassroomCurrentStatus(String classroomId) async {
    try {
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('classroomId', isEqualTo: classroomId)
          .where('day', isEqualTo: _selectedDay)
          .get();

      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['startTime'] as String;
        final endTime = data['endTime'] as String;

        if (_isCurrentlyInTimeSlot(startTime, endTime)) {
          return 'Occupied';
        }
      }

      return 'Available';
    } catch (e) {
      print('Error getting classroom status: $e');
      return 'Unknown';
    }
  }

  Future<String> _getClassroomCurrentSubject(String classroomId) async {
    try {
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('classroomId', isEqualTo: classroomId)
          .where('day', isEqualTo: _selectedDay)
          .get();

      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['startTime'] as String;
        final endTime = data['endTime'] as String;

        if (_isCurrentlyInTimeSlot(startTime, endTime)) {
          return data['subject'] as String;
        }
      }

      return '';
    } catch (e) {
      print('Error getting classroom subject: $e');
      return '';
    }
  }

  Future<void> _loadTeachers() async {
    try {
      QuerySnapshot teacherSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Teacher')
          .get();

      List<Map<String, dynamic>> teachers = [];

      for (var doc in teacherSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        teachers.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Teacher',
          'email': data['email'] ?? '',
          'isApproved': data['isTeacherApproved'] ?? false,
        });
      }

      setState(() {
        _teachers = teachers;
      });
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _loadTimetables() async {
    try {
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('day', isEqualTo: _selectedDay)
          .get();

      List<Map<String, dynamic>> timetables = [];

      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get classroom details
        DocumentSnapshot classroomDoc = await FirebaseFirestore.instance
            .collection('classrooms')
            .doc(data['classroomId'] as String)
            .get();

        // Get teacher details
        DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['teacherId'] as String)
            .get();

        String classroomName = 'Unknown';
        String teacherName = 'Unknown';

        if (classroomDoc.exists) {
          classroomName =
              (classroomDoc.data() as Map<String, dynamic>)['name'] ??
                  'Unknown';
        }

        if (teacherDoc.exists) {
          teacherName =
              (teacherDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
        }

        timetables.add({
          'id': doc.id,
          'day': data['day'] ?? 'Unknown',
          'startTime': data['startTime'] ?? '00:00',
          'endTime': data['endTime'] ?? '00:00',
          'subject': data['subject'] ?? 'Unknown',
          'teacherId': data['teacherId'] ?? '',
          'teacherName': teacherName,
          'classroomId': data['classroomId'] ?? '',
          'classroomName': classroomName,
          'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'] as String, data['endTime'] as String),
        });
      }

      // Sort timetables by start time
      timetables.sort((a, b) {
        return a['startTime'].compareTo(b['startTime']);
      });

      setState(() {
        _timetables = timetables;
      });
    } catch (e) {
      print('Error loading timetables: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Occupied':
        return Colors.red;
      case 'Maintenance':
        return Colors.orange;
      case 'Reserved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Fixed teacher schedule function
  void _showTeacherSchedule(String teacherId, String teacherName) async {
    try {
      setState(() {
        isLoading = true; // Show loading state
      });

      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('teacherId', isEqualTo: teacherId)
          .where('day', isEqualTo: _selectedDay)
          .get();

      List<Map<String, dynamic>> schedule = [];

      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get classroom details
        final classroomId = data['classroomId'] as String;
        DocumentSnapshot classroomDoc = await FirebaseFirestore.instance
            .collection('classrooms')
            .doc(classroomId)
            .get();

        String classroomName = 'Unknown';
        if (classroomDoc.exists) {
          classroomName =
              (classroomDoc.data() as Map<String, dynamic>)['name'] ??
                  'Unknown';
        }

        schedule.add({
          'startTime': data['startTime'],
          'endTime': data['endTime'],
          'subject': data['subject'],
          'classroomName': classroomName,
          'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'] as String, data['endTime'] as String),
        });
      }

      // Sort schedule by start time
      schedule.sort((a, b) {
        return a['startTime'].compareTo(b['startTime']);
      });

      setState(() {
        isLoading = false; // Hide loading state
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prof. $teacherName\'s Schedule',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDay,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: schedule.isEmpty
                    ? Center(
                        child: Text(
                          'No classes scheduled for $_selectedDay',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: schedule.length,
                        itemBuilder: (context, index) {
                          final item = schedule[index];
                          final isActive = item['isCurrentlyActive'];

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isActive
                                  ? const BorderSide(
                                      color: Colors.green, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['startTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.green
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'to',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${item['endTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.green
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['subject'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Room ${item['classroomName']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Current Class',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false; // Hide loading state on error
      });
      print('Error showing teacher schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load teacher schedule'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showClassroomSchedule(String classroomId, String roomNumber) async {
    try {
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('classroomId', isEqualTo: classroomId)
          .where('day', isEqualTo: _selectedDay)
          .get();

      List<Map<String, dynamic>> schedule = [];

      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get teacher details
        DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['teacherId'] as String)
            .get();

        String teacherName = 'Unknown';
        if (teacherDoc.exists) {
          teacherName =
              (teacherDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
        }

        schedule.add({
          'startTime': data['startTime'],
          'endTime': data['endTime'],
          'subject': data['subject'],
          'teacherName': teacherName,
          'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'] as String, data['endTime'] as String),
        });
      }

      // Sort schedule by start time
      schedule.sort((a, b) {
        return a['startTime'].compareTo(b['startTime']);
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Room $roomNumber Schedule',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _selectedDay,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: schedule.isEmpty
                    ? Center(
                        child: Text(
                          'No classes scheduled for today',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: schedule.length,
                        itemBuilder: (context, index) {
                          final item = schedule[index];
                          final isActive = item['isCurrentlyActive'];

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isActive
                                  ? const BorderSide(
                                      color: Colors.green, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['startTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.green
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'to',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${item['endTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.green
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['subject'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Prof. ${item['teacherName']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Current Class',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error showing classroom schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load classroom schedule'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDayPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Day',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ]
                    .map((day) => ListTile(
                          title: Text(day),
                          trailing: _selectedDay == day
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF6A11CB))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedDay = day;
                            });
                            Navigator.pop(context);

                            // Reload data for the new day
                            _loadTeacherLocations();
                            _loadClassrooms();
                            _loadTimetables();
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
          ),
        ),
      );
    }

    // Return appropriate screen based on selected index
    if (_selectedIndex == 1) {
      return ExploreScreen(); // This is a placeholder for your future ExploreScreen
    } else if (_selectedIndex == 2) {
      return ProfileScreen(
        userName: userName,
        userRole: userRole,
        currentUser: currentUser,
      );
    }

    // Home Screen UI
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6A11CB),
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDayPicker,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No new notifications'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('LOGOUT'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _currentTime = DateFormat('HH:mm').format(DateTime.now());
          });
          await _loadTeacherLocations();
          await _loadClassrooms();
          await _loadTimetables();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6A11CB),
                      Color(0xFF2575FC),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 36,
                          color: Color(0xFF6A11CB),
                        ),
                    ),
                      const SizedBox(width: 15),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${userName ?? 'User'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _selectedDay,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Current Time: $_currentTime',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Teacher Locations Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Teacher Locations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // View all teachers action
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFF6A11CB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 160,
                      child: _teacherLocations.isEmpty
                          ? Center(
                              child: Text(
                                'No teacher data available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _teacherLocations.length,
                              itemBuilder: (context, index) {
                                final teacher = _teacherLocations[index];
                                return GestureDetector(
                                  onTap: () => _showTeacherSchedule(
                                      teacher['id'], teacher['name']),
                                  child: Container(
                                    width: 160,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Color(0xFF6A11CB).withOpacity(0.1),
                                            child: Text(
                                              teacher['name'][0],
                                              style: const TextStyle(
                                                color: Color(0xFF6A11CB),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            teacher['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  teacher['currentLocation'],
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: teacher['currentLocation'] !=
                                                      'Faculty Room'
                                                  ? Colors.green.withOpacity(0.1)
                                                  : Colors.blue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              teacher['currentLocation'] !=
                                                      'Faculty Room'
                                                  ? 'In Class'
                                                  : 'Available',
                                              style: TextStyle(
                                                color: teacher['currentLocation'] !=
                                                        'Faculty Room'
                                                    ? Colors.green
                                                    : Colors.blue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Classroom Status Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Classroom Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // View all classrooms action
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFF6A11CB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 130,
                      child: _classrooms.isEmpty
                          ? Center(
                              child: Text(
                                'No classroom data available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _classrooms.length,
                              itemBuilder: (context, index) {
                                final classroom = _classrooms[index];
                                final status = classroom['status'] as String;
                                final subject = classroom['subject'] as String;
                                
                                return GestureDetector(
                                  onTap: () => _showClassroomSchedule(
                                      classroom['id'], classroom['roomNumber']),
                                  child: Container(
                                    width: 140,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status)
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              status == 'Available'
                                                  ? Icons.check_circle_outline
                                                  : Icons.access_time_filled,
                                              color: _getStatusColor(status),
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Room ${classroom['roomNumber']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${classroom['building']}, Floor ${classroom['floor']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Today's Timetable Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedDay\'s Timetable',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _timetables.isEmpty
                        ? Container(
                            height: 100,
                            alignment: Alignment.center,
                            child: Text(
                              'No classes scheduled for $_selectedDay',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _timetables.length,
                            itemBuilder: (context, index) {
                              final timetable = _timetables[index];
                              final isActive = timetable['isCurrentlyActive'];

                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isActive
                                      ? const BorderSide(
                                          color: Colors.green, width: 2)
                                      : BorderSide.none,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              timetable['startTime'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              'to',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              timetable['endTime'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              timetable['subject'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Prof. ${timetable['teacherName']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Room ${timetable['classroomName']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isActive)
                                              Container(
                                                margin:
                                                    const EdgeInsets.only(top: 8),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.green.withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Current Class',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 80), // Extra space at bottom for comfort
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF6A11CB),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
                      