import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // For teacher approval
  List<Map<String, dynamic>> _pendingTeachers = [];
  List<Map<String, dynamic>> _approvedTeachers = [];
  bool _isLoading = true;
  
  // For timetable management
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  String? _selectedTeacher;
  String? _selectedDay;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 9, minute: 0);
  
  // For classroom management
  final _classroomNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _floorController = TextEditingController();
  final _buildingController = TextEditingController();
  final _facilitiesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTeachers();
    _selectedDay = 'Monday';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    _classroomNameController.dispose();
    _capacityController.dispose();
    _floorController.dispose();
    _buildingController.dispose();
    _facilitiesController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeachers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot teacherSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Teacher')
          .get();

      _pendingTeachers = [];
      _approvedTeachers = [];

      for (var doc in teacherSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isApproved = data['isTeacherApproved'] ?? false;
        
        // Add user ID to the data map
        data['id'] = doc.id;
        
        if (isApproved) {
          _approvedTeachers.add(data);
        } else {
          _pendingTeachers.add(data);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error fetching teachers: $e');
    }
  }

  Future<void> _approveTeacher(String teacherId) async {
    try {
      await _firestore
          .collection('users')
          .doc(teacherId)
          .update({'isTeacherApproved': true});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teacher approved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      _fetchTeachers();
    } catch (e) {
      _showErrorSnackbar('Error approving teacher: $e');
    }
  }

  Future<void> _addTimetableEntry() async {
    if (_selectedTeacher == null || 
        _subjectController.text.isEmpty || 
        _roomController.text.isEmpty || 
        _selectedDay == null) {
      _showErrorSnackbar('Please fill all fields');
      return;
    }

    try {
      // Convert TimeOfDay to string
      final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';
      
      await _firestore.collection('timetable').add({
        'teacherId': _selectedTeacher,
        'subject': _subjectController.text.trim(),
        'room': _roomController.text.trim(),
        'day': _selectedDay,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _subjectController.clear();
      _roomController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timetable entry added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error adding timetable entry: $e');
    }
  }

  Future<void> _addClassroom() async {
    if (_classroomNameController.text.isEmpty || _capacityController.text.isEmpty) {
      _showErrorSnackbar('Classroom name and capacity are required');
      return;
    }

    try {
      int? capacity = int.tryParse(_capacityController.text);
      if (capacity == null) {
        _showErrorSnackbar('Capacity must be a number');
        return;
      }

      await _firestore.collection('classrooms').add({
        'name': _classroomNameController.text.trim(),
        'capacity': capacity,
        'floor': _floorController.text.trim(),
        'building': _buildingController.text.trim(),
        'facilities': _facilitiesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _classroomNameController.clear();
      _capacityController.clear();
      _floorController.clear();
      _buildingController.clear();
      _facilitiesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classroom added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error adding classroom: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.person_outline), text: 'Approve Teachers'),
            Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
            Tab(icon: Icon(Icons.meeting_room), text: 'Classrooms'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeacherApprovalTab(),
          _buildTimetableTab(),
          _buildClassroomTab(),
        ],
      ),
    );
  }

  Widget _buildTeacherApprovalTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Teacher Approvals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),
          SizedBox(height: 16),
          _pendingTeachers.isEmpty
              ? _buildEmptyState('No pending teacher approvals')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _pendingTeachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _pendingTeachers[index];
                    return _buildTeacherCard(
                      teacher: teacher,
                      isPending: true,
                    );
                  },
                ),
          SizedBox(height: 32),
          Text(
            'Approved Teachers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),
          SizedBox(height: 16),
          _approvedTeachers.isEmpty
              ? _buildEmptyState('No approved teachers yet')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _approvedTeachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _approvedTeachers[index];
                    return _buildTeacherCard(
                      teacher: teacher,
                      isPending: false,
                    );
                  },
                ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _fetchTeachers,
              icon: Icon(Icons.refresh),
              label: Text('Refresh List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6A11CB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard({
    required Map<String, dynamic> teacher,
    required bool isPending,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending ? Colors.orange : Colors.green,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF6A11CB).withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    (teacher['name'] as String?)?.isNotEmpty == true 
                        ? (teacher['name'] as String).substring(0, 1).toUpperCase() 
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A11CB),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unnamed Teacher',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        teacher['email'] ?? 'No email',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  ElevatedButton(
                    onPressed: () => _approveTeacher(teacher['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Approve'),
                  )
                else
                  Chip(
                    label: Text('Approved'),
                    backgroundColor: Colors.green[100],
                    labelStyle: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (teacher['specialization'] != null || teacher['department'] != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (teacher['department'] != null)
                      _buildTeacherInfoRow('Department', teacher['department']),
                    if (teacher['specialization'] != null)
                      _buildTeacherInfoRow('Specialization', teacher['specialization']),
                    if (teacher['experience'] != null)
                      _buildTeacherInfoRow('Experience', '${teacher['experience']} years'),
                    if (teacher['phoneNumber'] != null)
                      _buildTeacherInfoRow('Phone', teacher['phoneNumber']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Timetable Entry',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A11CB),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Teacher selection dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Teacher',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: _selectedTeacher,
                    items: _approvedTeachers.map((teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher['id'],
                        child: Text(teacher['name'] ?? 'Unnamed Teacher'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTeacher = value;
                      });
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Subject field
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      hintText: 'Enter subject name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Room field
                  TextFormField(
                    controller: _roomController,
                    decoration: InputDecoration(
                      labelText: 'Room',
                      hintText: 'Enter room number/name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Day selection
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    value: _selectedDay,
                    items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                        .map((day) => DropdownMenuItem<String>(
                              value: day,
                              child: Text(day),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDay = value;
                      });
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Time selection
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartTime,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _startTime.format(context),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _selectEndTime,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _endTime.format(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addTimetableEntry,
                        icon: Icon(Icons.add),
                        label: Text('Add Timetable Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          Text(
            'Timetable Entries',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Display timetable entries
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('timetable').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return _buildEmptyState('Error loading timetable: ${snapshot.error}');
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No timetable entries yet');
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final entry = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final entryId = snapshot.data!.docs[index].id;
                  
                  // Get teacher name
                  String teacherName = 'Loading...';
                  for (var teacher in _approvedTeachers) {
                    if (teacher['id'] == entry['teacherId']) {
                      teacherName = teacher['name'] ?? 'Unnamed Teacher';
                      break;
                    }
                  }
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        entry['subject'] ?? 'Unknown Subject',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text('Teacher: $teacherName'),
                          Text('Room: ${entry['room'] ?? 'Unknown'}'),
                          Text(
                            '${entry['day'] ?? 'Unknown'}, ${entry['startTime'] ?? '??:??'} - ${entry['endTime'] ?? '??:??'}',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            await _firestore.collection('timetable').doc(entryId).delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Timetable entry deleted'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            _showErrorSnackbar('Error deleting entry: $e');
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Classroom',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A11CB),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Classroom name field
                  TextFormField(
                    controller: _classroomNameController,
                    decoration: InputDecoration(
                      labelText: 'Classroom Name/Number',
                      hintText: 'Enter classroom name or number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Capacity field
                  TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Capacity',
                      hintText: 'Enter number of students',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.people),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Floor field
                  TextFormField(
                    controller: _floorController,
                    decoration: InputDecoration(
                      labelText: 'Floor',
                      hintText: 'Enter floor number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.layers),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Building field
                  TextFormField(
                    controller: _buildingController,
                    decoration: InputDecoration(
                      labelText: 'Building',
                      hintText: 'Enter building name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Facilities field
                  TextFormField(
                    controller: _facilitiesController,
                    decoration: InputDecoration(
                      labelText: 'Facilities',
                      hintText: 'Enter available facilities (e.g., projector, whiteboard)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.computer),
                    ),
                    maxLines: 3,
                  ),
                  
                  SizedBox(height: 24),
                  
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addClassroom,
                        icon: Icon(Icons.add),
                        label: Text('Add Classroom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          Text(
            'Classrooms',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Display classrooms
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('classrooms').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return _buildEmptyState('Error loading classrooms: ${snapshot.error}');
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No classrooms added yet');
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final classroom = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final classroomId = snapshot.data!.docs[index].id;
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  classroom['name'] ?? 'Unnamed Classroom',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  try {
                                    await _firestore.collection('classrooms').doc(classroomId).delete();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Classroom deleted'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    _showErrorSnackbar('Error deleting classroom: $e');
                                  }
                                },
                              ),
                            ],
                          ),
                          Divider(),
                          _buildClassroomInfoRow('Capacity', '${classroom['capacity'] ?? 'Unknown'} students'),
                          if (classroom['floor'] != null && classroom['floor'].toString().isNotEmpty)
                            _buildClassroomInfoRow('Floor', classroom['floor']),
                          if (classroom['building'] != null && classroom['building'].toString().isNotEmpty)
                            _buildClassroomInfoRow('Building', classroom['building']),
                          if (classroom['facilities'] != null && classroom['facilities'].toString().isNotEmpty)
                            _buildClassroomInfoRow('Facilities', classroom['facilities']),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}