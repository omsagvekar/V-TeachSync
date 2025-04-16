import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vteachsync/screens/home_screen.dart';
import 'package:vteachsync/screens/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;
  String searchQuery = '';
  int _selectedIndex = 1; // For bottom navigation
  
  // Selected day for timetable
  String _selectedDay = DateFormat('EEEE').format(DateTime.now()); // Current day
  String _currentTime = DateFormat('HH:mm').format(DateTime.now());

  // Lists to store data
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<Map<String, dynamic>> _filteredClassrooms = [];
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _allClassrooms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeachers();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      isLoading = true;
    });
    
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
          'subject': data['specialization'] ?? 'Not specified', // Changed from subject to specialization
          'department': data['department'] ?? 'Not specified',
          'isApproved': data['isTeacherApproved'] ?? false,
          'searchTerms': '${data['name']} ${data['specialization'] ?? ''} ${data['department'] ?? ''}'.toLowerCase(),
        });
      }

      setState(() {
        _allTeachers = teachers;
        _filteredTeachers = teachers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading teachers: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadClassrooms() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      QuerySnapshot classroomSnapshot = await FirebaseFirestore.instance
          .collection('classrooms')
          .get();

      List<Map<String, dynamic>> classrooms = [];

      for (var doc in classroomSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if classroom is currently occupied
        String status = await _getClassroomCurrentStatus(doc.id);
        
        classrooms.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'roomNumber': data['name'] ?? 'Unknown', // Using name as roomNumber
          'building': data['building'] ?? 'Unknown',
          'floor': data['floor'] ?? 'Unknown',
          'capacity': data['capacity'] ?? 0,
          'facilities': data['facilities'] ?? 'None',
          'status': status,
          'searchTerms': '${data['name']} ${data['building']} ${data['floor']}'.toLowerCase(),
        });
      }

      setState(() {
        _allClassrooms = classrooms;
        _filteredClassrooms = classrooms;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading classrooms: $e');
      setState(() {
        isLoading = false;
      });
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

  void _filterData() {
    if (searchQuery.trim().isEmpty) {
      setState(() {
        _filteredTeachers = _allTeachers;
        _filteredClassrooms = _allClassrooms;
      });
      return;
    }

    final query = searchQuery.toLowerCase();
    
    setState(() {
      _filteredTeachers = _allTeachers
          .where((teacher) => teacher['searchTerms'].contains(query))
          .toList();
      
      _filteredClassrooms = _allClassrooms
          .where((classroom) => classroom['searchTerms'].contains(query))
          .toList();
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }
  }

  void _showDayPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Day',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
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
                ].map((day) => ListTile(
                  title: Text(day),
                  trailing: _selectedDay == day
                      ? Icon(Icons.check_circle, color: Color(0xFF6A11CB))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                    Navigator.pop(context);
                    
                    // Reload data for the new day
                    _loadTeachers();
                    _loadClassrooms();
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeacherSchedule(String teacherId, String teacherName) async {
    try {
      setState(() {
        isLoading = true;
      });
      
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('teacherId', isEqualTo: teacherId)
          .where('day', isEqualTo: _selectedDay)
          .get();
      
      List<Map<String, dynamic>> schedule = [];
      
      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        try {
          // Get classroom details
          DocumentSnapshot classroomDoc = await FirebaseFirestore.instance
              .collection('classrooms')
              .doc(data['classroomId'])
              .get();
          
          String classroomName = 'Unknown';
          if (classroomDoc.exists) {
            final classroomData = classroomDoc.data() as Map<String, dynamic>;
            classroomName = classroomData['name'] ?? 'Unknown';
          }
          
          schedule.add({
            'startTime': data['startTime'],
            'endTime': data['endTime'],
            'subject': data['subject'],
            'classroomName': classroomName,
            'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'],
              data['endTime']
            ),
          });
        } catch (e) {
          print('Error fetching classroom detail: $e');
          // Still add the schedule item even if classroom details fail
          schedule.add({
            'startTime': data['startTime'],
            'endTime': data['endTime'],
            'subject': data['subject'],
            'classroomName': 'Unknown',
            'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'],
              data['endTime']
            ),
          });
        }
      }
      
      setState(() {
        isLoading = false;
      });
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$teacherName\'s Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    _selectedDay,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
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
                            margin: EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isActive
                                  ? BorderSide(color: Colors.green, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['startTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? Colors.green : Colors.black87,
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
                                            color: isActive ? Colors.green : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['subject'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Room ${item['classroomName']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
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
        isLoading = false;
      });
      print('Error showing teacher schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load teacher schedule: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showClassroomSchedule(String classroomId, String roomNumber) async {
    try {
      setState(() {
        isLoading = true;
      });
      
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('classroomId', isEqualTo: classroomId)
          .where('day', isEqualTo: _selectedDay)
          .get();
      
      List<Map<String, dynamic>> schedule = [];
      
      for (var doc in timetableSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        try {
          // Get teacher details
          DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['teacherId'])
              .get();
          
          String teacherName = 'Unknown';
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>;
            teacherName = teacherData['name'] ?? 'Unknown';
          }
          
          schedule.add({
            'startTime': data['startTime'],
            'endTime': data['endTime'],
            'subject': data['subject'],
            'teacherName': teacherName,
            'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'],
              data['endTime']
            ),
          });
        } catch (e) {
          print('Error fetching teacher detail: $e');
          // Still add the schedule item even if teacher details fail
          schedule.add({
            'startTime': data['startTime'],
            'endTime': data['endTime'],
            'subject': data['subject'],
            'teacherName': 'Unknown',
            'isCurrentlyActive': _isCurrentlyInTimeSlot(
              data['startTime'],
              data['endTime']
            ),
          });
        }
      }
      
      setState(() {
        isLoading = false;
      });
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Room $roomNumber Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Text(
                    _selectedDay,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
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
                            margin: EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isActive
                                  ? BorderSide(color: Colors.green, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['startTime']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? Colors.green : Colors.black87,
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
                                            color: isActive ? Colors.green : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['subject'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${item['teacherName']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
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
        isLoading = false;
      });
      print('Error showing classroom schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load classroom schedule: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  Future<void> _refreshData() async {
    await _loadTeachers();
    await _loadClassrooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF6A11CB),
        title: Text(
          'Explore',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _showDayPicker,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Teachers'),
            Tab(text: 'Classrooms'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
                ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                _filterData();
              },
            ),
          ),
          
          // Current day indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Color(0xFF6A11CB),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Viewing: $_selectedDay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Text(
                    _currentTime,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6A11CB),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.access_time,
                    color: Color(0xFF6A11CB),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Tab content
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Teachers tab
                        _filteredTeachers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      searchQuery.isEmpty
                                          ? 'No teachers available'
                                          : 'No teachers found for "$searchQuery"',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(16),
                                itemCount: _filteredTeachers.length,
                                itemBuilder: (context, index) {
                                  final teacher = _filteredTeachers[index];
                                  return Card(
                                    elevation: 1,
                                    margin: EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _showTeacherSchedule(teacher['id'], teacher['name']),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 25,
                                              backgroundColor: Color(0xFF6A11CB).withOpacity(0.1),
                                              child: Text(
                                                teacher['name'].toString().substring(0, 1).toUpperCase(),
                                                style: TextStyle(
                                                  color: Color(0xFF6A11CB),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    teacher['name'],
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    teacher['subject'],
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (teacher['department'] != 'Not specified')
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4.0),
                                                      child: Text(
                                                        teacher['department'],
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey[400],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        
                        // Classrooms tab
                        _filteredClassrooms.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      searchQuery.isEmpty
                                          ? 'No classrooms available'
                                          : 'No classrooms found for "$searchQuery"',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.all(16),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.1,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: _filteredClassrooms.length,
                                itemBuilder: (context, index) {
                                  final classroom = _filteredClassrooms[index];
                                  return Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _showClassroomSchedule(
                                          classroom['id'], classroom['roomNumber']),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Room ${classroom['roomNumber']}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                            classroom['status'])
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    classroom['status'],
                                                    style: TextStyle(
                                                      color: _getStatusColor(
                                                          classroom['status']),
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '${classroom['building']}, Floor ${classroom['floor']}',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Capacity: ${classroom['capacity']}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Spacer(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'View Schedule',
                                                  style: TextStyle(
                                                    color: Color(0xFF6A11CB),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right,
                                                  size: 16,
                                                  color: Color(0xFF6A11CB),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color(0xFF6A11CB),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}