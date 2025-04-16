import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFirestore _auth = FirebaseFirestore.instance;
  
  // For teacher management
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherPhoneController = TextEditingController();
  final _teacherDepartmentController = TextEditingController();
  final _teacherSpecializationController = TextEditingController();
  final _teacherExperienceController = TextEditingController();

  // For timetable management
  final _subjectController = TextEditingController();
  String? _selectedTeacher;
  String? _selectedClassroom;
  String? _selectedDay;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 9, minute: 0);
  List<Map<String, dynamic>> _classrooms = [];

  // For classroom management
  final _classroomNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _floorController = TextEditingController();
  final _buildingController = TextEditingController();
  final _facilitiesController = TextEditingController();

  // For checking admin status
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchTeachers();
    _fetchClassrooms();
    _selectedDay = 'Monday';
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _teacherEmailController.dispose();
    _teacherPhoneController.dispose();
    _teacherDepartmentController.dispose();
    _teacherSpecializationController.dispose();
    _teacherExperienceController.dispose();
    _subjectController.dispose();
    _classroomNameController.dispose();
    _capacityController.dispose();
    _floorController.dispose();
    _buildingController.dispose();
    _facilitiesController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _isAdmin = userData['role'] == 'Admin';
        });
      }
    }

    if (!_isAdmin) {
      Future.delayed(Duration.zero, () {
        _showErrorSnackbar('You do not have admin privileges.');
      });
    }
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

      _teachers = [];

      for (var doc in teacherSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Add user ID to the data map
        data['id'] = doc.id;
        _teachers.add(data);
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

  Future<void> _fetchClassrooms() async {
    try {
      final QuerySnapshot classroomsSnapshot =
          await _firestore.collection('classrooms').get();

      setState(() {
        _classrooms = classroomsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      _showErrorSnackbar('Error fetching classrooms: $e');
    }
  }

  Future<void> _addTeacher() async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to add teachers.');
      return;
    }

    if (_teacherNameController.text.isEmpty || _teacherEmailController.text.isEmpty) {
      _showErrorSnackbar('Teacher name and email are required');
      return;
    }

    try {
      // Create teacher document in Firestore
      await _firestore.collection('users').add({
        'name': _teacherNameController.text.trim(),
        'email': _teacherEmailController.text.trim(),
        'phoneNumber': _teacherPhoneController.text.trim(),
        'department': _teacherDepartmentController.text.trim(),
        'specialization': _teacherSpecializationController.text.trim(),
        'experience': _teacherExperienceController.text.trim(),
        'role': 'Teacher',
        'isTeacherApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Clear form fields
      _teacherNameController.clear();
      _teacherEmailController.clear();
      _teacherPhoneController.clear();
      _teacherDepartmentController.clear();
      _teacherSpecializationController.clear();
      _teacherExperienceController.clear();

      // Refresh teacher list
      _fetchTeachers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teacher added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error adding teacher: $e');
    }
  }

  Future<void> _deleteTeacher(String teacherId) async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to delete teachers.');
      return;
    }

    try {
      await _firestore.collection('users').doc(teacherId).delete();
      
      // Refresh teacher list
      _fetchTeachers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teacher deleted successfully!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error deleting teacher: $e');
    }
  }

  Future<void> _addTimetableEntry() async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to add timetable entries.');
      return;
    }

    if (_selectedTeacher == null ||
        _subjectController.text.isEmpty ||
        _selectedClassroom == null ||
        _selectedDay == null) {
      _showErrorSnackbar('Please fill all fields');
      return;
    }

    try {
      // Convert TimeOfDay to string
      final startTimeStr =
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr =
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      await _firestore.collection('timetables').add({
        'teacherId': _selectedTeacher,
        'subject': _subjectController.text.trim(),
        'classroomId': _selectedClassroom,
        'day': _selectedDay,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      _subjectController.clear();
      setState(() {
        _selectedClassroom = null;
      });

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
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to add classrooms.');
      return;
    }

    if (_classroomNameController.text.isEmpty ||
        _capacityController.text.isEmpty) {
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
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      _classroomNameController.clear();
      _capacityController.clear();
      _floorController.clear();
      _buildingController.clear();
      _facilitiesController.clear();

      _fetchClassrooms();

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

  void _logout() {
    FirebaseAuth.instance.signOut().then((_) {
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/login', // Make sure this route is defined in your routes
        (route) => false,
      );
    }).catchError((error) {
      _showErrorSnackbar('Error logging out: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel - TeachSync',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _getPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color(0xFF6A11CB),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Teacher Management',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Timetable',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.meeting_room),
            label: 'Classrooms',
          ),
        ],
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildTeacherManagementTab();
      case 1:
        return _buildTimetableTab();
      case 2:
        return _buildClassroomTab();
      default:
        return _buildTeacherManagementTab();
    }
  }

  Widget _buildTeacherManagementTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Teacher Form
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
                      'Add New Teacher',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A11CB),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Teacher Name field
                    TextFormField(
                      controller: _teacherNameController,
                      decoration: InputDecoration(
                        labelText: 'Teacher Name',
                        hintText: 'Enter full name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Teacher Email field
                    TextFormField(
                      controller: _teacherEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Teacher Phone field
                    TextFormField(
                      controller: _teacherPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Department field
                    TextFormField(
                      controller: _teacherDepartmentController,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        hintText: 'Enter department',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Specialization field
                    TextFormField(
                      controller: _teacherSpecializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        hintText: 'Enter specialization',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Experience field
                    TextFormField(
                      controller: _teacherExperienceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Experience (Years)',
                        hintText: 'Enter years of experience',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.work),
                      ),
                    ),

                    SizedBox(height: 24),

                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAdmin ? _addTeacher : null,
                          icon: Icon(Icons.add),
                          label: Text('Add Teacher'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
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
              'Teacher List',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A11CB),
              ),
            ),

            SizedBox(height: 16),

            // Teacher List
            _teachers.isEmpty
                ? _buildEmptyState('No teachers added yet')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _teachers.length,
                    itemBuilder: (context, index) {
                      final teacher = _teachers[index];
                      return _buildTeacherCard(teacher: teacher);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard({
    required Map<String, dynamic> teacher,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green,
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
                        ? (teacher['name'] as String)
                            .substring(0, 1)
                            .toUpperCase()
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
                if (_isAdmin)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTeacher(teacher['id']),
                  ),
              ],
            ),
            SizedBox(height: 12),
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
                    _buildInfoRow('Department', teacher['department']),
                  if (teacher['specialization'] != null)
                    _buildInfoRow('Specialization', teacher['specialization']),
                  if (teacher['experience'] != null)
                    _buildInfoRow('Experience', '${teacher['experience']} years'),
                  if (teacher['phoneNumber'] != null)
                    _buildInfoRow('Phone', teacher['phoneNumber']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                    'Timetable Management',
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
                    items: _teachers.map((teacher) {
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

                  // Classroom selection dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Classroom',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                    value: _selectedClassroom,
                    items: _classrooms.map((classroom) {
                      final String details =
                          'Capacity: ${classroom['capacity'] ?? '?'}, ' +
                              (classroom['floor'] != null
                                  ? 'Floor: ${classroom['floor']}, '
                                  : '') +
                              (classroom['building'] != null
                                  ? 'Building: ${classroom['building']}'
                                  : '');

                      return DropdownMenuItem<String>(
                        value: classroom['id'],
                        child: Text('${classroom['name']} ($details)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClassroom = value;
                      });
                    },
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
                    items: [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday'
                    ]
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
                        onPressed: _isAdmin ? _addTimetableEntry : null,
                        icon: Icon(Icons.add),
                        label: Text('Add Timetable Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
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
            stream: _firestore
                .collection('timetables')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildEmptyState(
                    'Error loading timetable: ${snapshot.error}');
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No timetable entries yet');
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final entry =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final entryId = snapshot.data!.docs[index].id;

                  // Get teacher name
                  String teacherName = 'Unknown Teacher';
                  String classroomName = 'Unknown Classroom';

                  for (var teacher in _teachers) {
                    if (teacher['id'] == entry['teacherId']) {
                      teacherName = teacher['name'] ?? 'Unnamed Teacher';
                      break;
                    }
                  }

                  for (var classroom in _classrooms) {
                    if (classroom['id'] == entry['classroomId']) {
                      classroomName = classroom['name'] ?? 'Unnamed Classroom';
                      break;
                    }
                  }

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Text('Classroom: $classroomName'),
                          Text('Day: ${entry['day'] ?? 'Unknown'}'),
                          Text('Time: ${entry['startTime'] ?? '?'} - ${entry['endTime'] ?? '?'}'),
                        ],
                      ),
                      trailing: _isAdmin
                          ? IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                try {
                                  await _firestore
                                      .collection('timetables')
                                      .doc(entryId)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Timetable entry deleted'),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  _showErrorSnackbar(
                                      'Error deleting entry: $e');
                                }
                              },
                            )
                          : null,
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
                      hintText: 'e.g., Room 101',
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
                      hintText: 'Enter max number of students',
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
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Facilities field
                  TextFormField(
                    controller: _facilitiesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Facilities',
                      hintText: 'e.g., Projector, Whiteboard, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.devices_other),
                    ),
                  ),

                  SizedBox(height: 24),

                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAdmin ? _addClassroom : null,
                        icon: Icon(Icons.add),
                        label: Text('Add Classroom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
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
            'Classroom List',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A11CB),
            ),
          ),

          SizedBox(height: 16),

          // Display classroom list
          _classrooms.isEmpty
              ? _buildEmptyState('No classrooms added yet')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _classrooms.length,
                  itemBuilder: (context, index) {
                    final classroom = _classrooms[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          classroom['name'] ?? 'Unnamed Classroom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('Capacity: ${classroom['capacity'] ?? 'Unknown'}'),
                            if (classroom['floor'] != null)
                              Text('Floor: ${classroom['floor']}'),
                            if (classroom['building'] != null)
                              Text('Building: ${classroom['building']}'),
                            if (classroom['facilities'] != null)
                              Text('Facilities: ${classroom['facilities']}'),
                          ],
                        ),
                        trailing: _isAdmin
                            ? IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  try {
                                    await _firestore
                                        .collection('classrooms')
                                        .doc(classroom['id'])
                                        .delete();
                                    _fetchClassrooms();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Classroom deleted'),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    _showErrorSnackbar(
                                        'Error deleting classroom: $e');
                                  }
                                },
                              )
                            : null,
                      ),
                    );
                  },
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
              Icons.info_outline,
              size: 48,
              color: Colors.grey,
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