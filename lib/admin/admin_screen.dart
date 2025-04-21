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
  final FirebaseAuth _auth = FirebaseAuth.instance; // Fixed: Use FirebaseAuth instead of FirebaseFirestore
  
  // For teacher management
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherPhoneController = TextEditingController();
  final _teacherDepartmentController = TextEditingController();
  final _teacherSpecializationController = TextEditingController();
  final _teacherExperienceController = TextEditingController();
  bool _isEditing = false;
  String? _editingTeacherId;

  // For timetable management
  final _subjectController = TextEditingController();
  String? _selectedTeacher;
  String? _selectedClassroom;
  String? _selectedDay;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 9, minute: 0);
  List<Map<String, dynamic>> _classrooms = [];
  bool _isEditingTimetable = false;
  String? _editingTimetableId;

  // For classroom management
  final _classroomNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _floorController = TextEditingController();
  final _buildingController = TextEditingController();
  final _facilitiesController = TextEditingController();
  bool _isEditingClassroom = false;
  String? _editingClassroomId;

  // For checking admin status
  bool _isAdmin = false;
  String? _currentUserId;

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
      _currentUserId = user.uid;
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

  // Reset all teacher form fields
  void _resetTeacherForm() {
    setState(() {
      _isEditing = false;
      _editingTeacherId = null;
      _teacherNameController.clear();
      _teacherEmailController.clear();
      _teacherPhoneController.clear();
      _teacherDepartmentController.clear();
      _teacherSpecializationController.clear();
      _teacherExperienceController.clear();
    });
  }

  // Reset all classroom form fields
  void _resetClassroomForm() {
    setState(() {
      _isEditingClassroom = false;
      _editingClassroomId = null;
      _classroomNameController.clear();
      _capacityController.clear();
      _floorController.clear();
      _buildingController.clear();
      _facilitiesController.clear();
    });
  }

  // Reset all timetable form fields
  void _resetTimetableForm() {
    setState(() {
      _isEditingTimetable = false;
      _editingTimetableId = null;
      _subjectController.clear();
      _selectedTeacher = null;
      _selectedClassroom = null;
      _selectedDay = 'Monday';
      _startTime = TimeOfDay(hour: 8, minute: 0);
      _endTime = TimeOfDay(hour: 9, minute: 0);
    });
  }

  Future<void> _addOrUpdateTeacher() async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to manage teachers.');
      return;
    }

    if (_teacherNameController.text.isEmpty || _teacherEmailController.text.isEmpty) {
      _showErrorSnackbar('Teacher name and email are required');
      return;
    }

    try {
      final Map<String, dynamic> teacherData = {
        'name': _teacherNameController.text.trim(),
        'email': _teacherEmailController.text.trim(),
        'phoneNumber': _teacherPhoneController.text.trim(),
        'department': _teacherDepartmentController.text.trim(),
        'specialization': _teacherSpecializationController.text.trim(),
        'experience': _teacherExperienceController.text.trim(),
        'role': 'Teacher',
        'isTeacherApproved': true,
      };

      if (_isEditing && _editingTeacherId != null) {
        // Update existing teacher
        await _firestore.collection('users').doc(_editingTeacherId).update(teacherData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Teacher updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Create new teacher
        teacherData['createdAt'] = FieldValue.serverTimestamp();
        teacherData['createdBy'] = _currentUserId;

        await _firestore.collection('users').add(teacherData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Teacher added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reset form and refresh teacher list
      _resetTeacherForm();
      _fetchTeachers();

    } catch (e) {
      _showErrorSnackbar('Error ${_isEditing ? 'updating' : 'adding'} teacher: $e');
    }
  }

  void _editTeacher(Map<String, dynamic> teacher) {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to edit teachers.');
      return;
    }

    setState(() {
      _isEditing = true;
      _editingTeacherId = teacher['id'];
      _teacherNameController.text = teacher['name'] ?? '';
      _teacherEmailController.text = teacher['email'] ?? '';
      _teacherPhoneController.text = teacher['phoneNumber'] ?? '';
      _teacherDepartmentController.text = teacher['department'] ?? '';
      _teacherSpecializationController.text = teacher['specialization'] ?? '';
      _teacherExperienceController.text = teacher['experience']?.toString() ?? '';
    });

    // Scroll to top of teacher form
    Scrollable.ensureVisible(
      context,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _deleteTeacher(String teacherId) async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to delete teachers.');
      return;
    }

    try {
      // Show confirmation dialog
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this teacher? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

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

  Future<void> _addOrUpdateTimetableEntry() async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to manage timetable entries.');
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

      final Map<String, dynamic> timetableData = {
        'teacherId': _selectedTeacher,
        'subject': _subjectController.text.trim(),
        'classroomId': _selectedClassroom,
        'day': _selectedDay,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
      };

      if (_isEditingTimetable && _editingTimetableId != null) {
        // Update existing timetable entry
        await _firestore.collection('timetables').doc(_editingTimetableId).update(timetableData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timetable entry updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Create new timetable entry
        timetableData['createdAt'] = FieldValue.serverTimestamp();
        timetableData['createdBy'] = _currentUserId;

        await _firestore.collection('timetables').add(timetableData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timetable entry added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reset form
      _resetTimetableForm();

    } catch (e) {
      _showErrorSnackbar('Error ${_isEditingTimetable ? 'updating' : 'adding'} timetable entry: $e');
    }
  }

  void _editTimetableEntry(Map<String, dynamic> entry, String entryId) {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to edit timetable entries.');
      return;
    }

    setState(() {
      _isEditingTimetable = true;
      _editingTimetableId = entryId;
      _selectedTeacher = entry['teacherId'];
      _subjectController.text = entry['subject'] ?? '';
      _selectedClassroom = entry['classroomId'];
      _selectedDay = entry['day'];
      
      // Parse time strings
      if (entry['startTime'] != null) {
        final timeParts = entry['startTime'].split(':');
        if (timeParts.length == 2) {
          _startTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }
      
      if (entry['endTime'] != null) {
        final timeParts = entry['endTime'].split(':');
        if (timeParts.length == 2) {
          _endTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }
    });

    // Scroll to top of timetable form
    Scrollable.ensureVisible(
      context,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addOrUpdateClassroom() async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to manage classrooms.');
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

      final Map<String, dynamic> classroomData = {
        'name': _classroomNameController.text.trim(),
        'capacity': capacity,
        'floor': _floorController.text.trim(),
        'building': _buildingController.text.trim(),
        'facilities': _facilitiesController.text.trim(),
      };

      if (_isEditingClassroom && _editingClassroomId != null) {
        // Update existing classroom
        await _firestore.collection('classrooms').doc(_editingClassroomId).update(classroomData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Create new classroom
        classroomData['createdAt'] = FieldValue.serverTimestamp();
        classroomData['createdBy'] = _currentUserId;

        await _firestore.collection('classrooms').add(classroomData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classroom added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Reset form and refresh classroom list
      _resetClassroomForm();
      _fetchClassrooms();

    } catch (e) {
      _showErrorSnackbar('Error ${_isEditingClassroom ? 'updating' : 'adding'} classroom: $e');
    }
  }

  void _editClassroom(Map<String, dynamic> classroom) {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to edit classrooms.');
      return;
    }

    setState(() {
      _isEditingClassroom = true;
      _editingClassroomId = classroom['id'];
      _classroomNameController.text = classroom['name'] ?? '';
      _capacityController.text = classroom['capacity']?.toString() ?? '';
      _floorController.text = classroom['floor'] ?? '';
      _buildingController.text = classroom['building'] ?? '';
      _facilitiesController.text = classroom['facilities'] ?? '';
    });

    // Scroll to top of classroom form
    Scrollable.ensureVisible(
      context,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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

  void _logout() async {
    try {
      await _auth.signOut(); // Fixed: Use _auth instead of FirebaseAuth.instance
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (error) {
      _showErrorSnackbar('Error logging out: $error');
    }
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
                      _isEditing ? 'Edit Teacher' : 'Add New Teacher',
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

                    Row(
                      children: [
                        if (_isEditing)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resetTeacherForm,
                              icon: Icon(Icons.cancel),
                              label: Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        if (_isEditing) SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAdmin ? _addOrUpdateTeacher : null,
                            icon: Icon(_isEditing ? Icons.save : Icons.add),
                            label: Text(_isEditing ? 'Update Teacher' : 'Add Teacher'),
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
                      ],
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTeacher(teacher),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTeacher(teacher['id']),
                      ),
                    ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTeacherInfoRow(
                              Icons.phone,
                              'Phone:',
                              teacher['phoneNumber'] ?? 'Not provided',
                            ),
                            SizedBox(height: 8),
                            _buildTeacherInfoRow(
                              Icons.business,
                              'Department:',
                              teacher['department'] ?? 'Not provided',
                            ),
                            SizedBox(height: 8),
                            _buildTeacherInfoRow(
                              Icons.school,
                              'Specialization:',
                              teacher['specialization'] ?? 'Not provided',
                            ),
                            SizedBox(height: 8),
                            _buildTeacherInfoRow(
                              Icons.work,
                              'Experience:',
                              '${teacher['experience'] ?? 'Not provided'} ${teacher['experience'] != null && teacher['experience'].toString() != "1" ? 'years' : 'year'}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
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
    );
  }

  Widget _buildTimetableTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Timetable Entry Form
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
                      _isEditingTimetable ? 'Edit Timetable Entry' : 'Add New Timetable Entry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A11CB),
                      ),
                    ),
                    SizedBox(height: 24),

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

                    // Teacher dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedTeacher,
                      onChanged: (value) {
                        setState(() {
                          _selectedTeacher = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Teacher',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _teachers.map((teacher) {
                        return DropdownMenuItem<String>(
                          value: teacher['id'],
                          child: Text(teacher['name'] ?? 'Unnamed Teacher'),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 16),

                    // Classroom dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedClassroom,
                      onChanged: (value) {
                        setState(() {
                          _selectedClassroom = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Classroom',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                      items: _classrooms.map((classroom) {
                        return DropdownMenuItem<String>(
                          value: classroom['id'],
                          child: Text(classroom['name'] ?? 'Unnamed Classroom'),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 16),

                    // Day dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedDay,
                      onChanged: (value) {
                        setState(() {
                          _selectedDay = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Day',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday'
                      ].map((day) {
                        return DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        );
                      }).toList(),
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
                                '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
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
                                '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    Row(
                      children: [
                        if (_isEditingTimetable)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resetTimetableForm,
                              icon: Icon(Icons.cancel),
                              label: Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        if (_isEditingTimetable) SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAdmin ? _addOrUpdateTimetableEntry : null,
                            icon: Icon(_isEditingTimetable ? Icons.save : Icons.add),
                            label:
                                Text(_isEditingTimetable ? 'Update Entry' : 'Add Entry'),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            Text(
              'Current Timetable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A11CB),
              ),
            ),

            SizedBox(height: 16),

            // Timetable display
            FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('timetables').get(),
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

                List<DocumentSnapshot> entries = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index].data() as Map<String, dynamic>;
                    final entryId = entries[index].id;

                    return _buildTimetableEntryCard(entry: entry, entryId: entryId);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableEntryCard({
    required Map<String, dynamic> entry,
    required String entryId,
  }) {
    String teacherName = 'Loading...';
    String classroomName = 'Loading...';

    // Find teacher name
    for (var teacher in _teachers) {
      if (teacher['id'] == entry['teacherId']) {
        teacherName = teacher['name'] ?? 'Unknown Teacher';
        break;
      }
    }

    // Find classroom name
    for (var classroom in _classrooms) {
      if (classroom['id'] == entry['classroomId']) {
        classroomName = classroom['name'] ?? 'Unknown Classroom';
        break;
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6A11CB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: Color(0xFF6A11CB),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['subject'] ?? 'No Subject',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${entry['day'] ?? 'No Day'}, ${entry['startTime'] ?? '00:00'} - ${entry['endTime'] ?? '00:00'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTimetableEntry(entry, entryId),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTimetableEntry(entryId),
                      ),
                    ],
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
                  _buildInfoRow(Icons.person, 'Teacher:', teacherName),
                  SizedBox(height: 8),
                  _buildInfoRow(Icons.meeting_room, 'Classroom:', classroomName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTimetableEntry(String entryId) async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to delete timetable entries.');
      return;
    }

    try {
      // Show confirmation dialog
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete this timetable entry? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      await _firestore.collection('timetables').doc(entryId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timetable entry deleted successfully!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Re-fetch timetable entries (handled by FutureBuilder)
      setState(() {});
    } catch (e) {
      _showErrorSnackbar('Error deleting timetable entry: $e');
    }
  }

  Widget _buildClassroomTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Classroom Form
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
                      _isEditingClassroom ? 'Edit Classroom' : 'Add New Classroom',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A11CB),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Classroom Name field
                    TextFormField(
                      controller: _classroomNameController,
                      decoration: InputDecoration(
                        labelText: 'Classroom Name',
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
                        hintText: 'Enter maximum capacity',
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
                        hintText: 'Enter available facilities',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),

                    SizedBox(height: 24),

                    Row(
                      children: [
                        if (_isEditingClassroom)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resetClassroomForm,
                              icon: Icon(Icons.cancel),
                              label: Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        if (_isEditingClassroom) SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAdmin ? _addOrUpdateClassroom : null,
                            icon: Icon(_isEditingClassroom ? Icons.save : Icons.add),
                            label: Text(_isEditingClassroom ? 'Update Classroom' : 'Add Classroom'),
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
                      ],
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

            // Classroom List
            _classrooms.isEmpty
                ? _buildEmptyState('No classrooms added yet')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _classrooms.length,
                    itemBuilder: (context, index) {
                      final classroom = _classrooms[index];
                      return _buildClassroomCard(classroom: classroom);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassroomCard({
    required Map<String, dynamic> classroom,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6A11CB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.meeting_room,
                    color: Color(0xFF6A11CB),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom['name'] ?? 'Unnamed Classroom',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Capacity: ${classroom['capacity'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editClassroom(classroom),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteClassroom(classroom['id']),
                      ),
                    ],
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
                  _buildInfoRow(Icons.layers, 'Floor:', classroom['floor'] ?? 'Not specified'),
                  SizedBox(height: 8),
                  _buildInfoRow(
                      Icons.business, 'Building:', classroom['building'] ?? 'Not specified'),
                  SizedBox(height: 8),
                  _buildInfoRow(
                      Icons.computer, 'Facilities:', classroom['facilities'] ?? 'Not specified'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteClassroom(String classroomId) async {
    if (!_isAdmin) {
      _showErrorSnackbar('You need admin privileges to delete classrooms.');
      return;
    }

    try {
      // Show confirmation dialog
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete this classroom? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      await _firestore.collection('classrooms').doc(classroomId).delete();
      
      // Check and delete related timetable entries
      final timetableEntries = await _firestore
          .collection('timetables')
          .where('classroomId', isEqualTo: classroomId)
          .get();
      
      for (var doc in timetableEntries.docs) {
        await doc.reference.delete();
      }

      // Refresh classroom list
      _fetchClassrooms();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classroom deleted successfully!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error deleting classroom: $e');
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}