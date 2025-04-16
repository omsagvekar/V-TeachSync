import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vteachsync/auth/login_screen.dart';
import 'package:vteachsync/screens/home_screen.dart';
import 'package:vteachsync/screens/explore_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userName;
  final String? userRole;
  final User? currentUser;

  const ProfileScreen({super.key, this.userName, this.userRole, this.currentUser});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _recentActivities = [];
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  int _selectedIndex = 2; // For bottom navigation

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadRecentActivities();
  }

  Future<void> _loadUserDetails() async {
    try {
      if (widget.currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser!.uid)
          .get();
          
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading detailed user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentActivities() async {
    // In a real app, you would fetch this from Firestore
    // For now, we'll use static data
    setState(() {
      _recentActivities = [
        {
          'title': 'Account Created',
          'date': '25 Feb 2025',
          'icon': Icons.person_add_rounded,
          'color': Color(0xFF6A11CB),
          'details': 'Your account was successfully created.'
        },
        {
          'title': 'Profile Updated',
          'date': '25 Feb 2025',
          'icon': Icons.edit_rounded,
          'color': Color(0xFF2575FC),
          'details': 'You updated your profile information.'
        },
        {
          'title': 'Settings Changed',
          'date': '25 Feb 2025',
          'icon': Icons.settings_rounded,
          'color': Colors.orange,
          'details': 'You updated your notification settings.'
        },
        {
          'title': 'App Login',
          'date': '19 Mar 2025',
          'icon': Icons.login_rounded,
          'color': Colors.green,
          'details': 'You logged in from a new device.'
        },
      ];
    });
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: widget.userName);
    final bioController = TextEditingController(text: _userData['bio'] ?? 'No bio available.');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Here you would update the user data in Firestore
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile updated successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context);
            },
            child: Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ExploreScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.userName ?? widget.currentUser?.email?.split('@')[0] ?? 'User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF6A11CB),
                      Color(0xFF2575FC),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        (widget.userName ?? 'U').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A11CB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined),
                onPressed: _showEditProfileDialog,
                tooltip: 'Edit Profile',
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded),
                onPressed: () async {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Logout'),
                      content: Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => LoginPage()),
                              (route) => false,
                            );
                          },
                          child: Text('LOGOUT'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Email Row
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: Color(0xFF6A11CB),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Email:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.currentUser?.email ?? 'No email available',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          
                          // Role Row
                          Row(
                            children: [
                              Icon(
                                widget.userRole == 'teacher' ? Icons.school_outlined : 
                                widget.userRole == 'admin' ? Icons.admin_panel_settings_outlined : 
                                Icons.person_outline,
                                color: Color(0xFF6A11CB),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Role:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.userRole?.capitalize() ?? 'Student',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          
                          // Bio Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF6A11CB),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Bio:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userData['bio'] ?? 'No bio available.',
                                  style: TextStyle(
                                    color: Colors.grey[700],
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
                  
                  // Recent Activities
                  Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Activity List
                  ..._recentActivities.map((activity) => Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: activity['color'],
                        child: Icon(
                          activity['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        activity['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            activity['details'],
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            activity['date'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  )),
                  
                  SizedBox(height: 24),
                  
                  // Settings Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.settings_outlined,
                            color: Color(0xFF6A11CB),
                          ),
                          title: Text(
                            'Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            // Navigate to settings page
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.help_outline,
                            color: Color(0xFF6A11CB),
                          ),
                          title: Text(
                            'Help & Support',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            // Navigate to help page
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.privacy_tip_outlined,
                            color: Color(0xFF6A11CB),
                          ),
                          title: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            // Navigate to privacy policy page
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // App Version
                  Center(
                    child: Text(
                      'VTeachSync v1.0.0',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
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

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}