import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  String _filterCategory = "All";
  
  List<String> _categories = ["All", "Teachers", "Classrooms", "Subjects"];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      searchQuery = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Explore',
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
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search for teachers or classrooms...",
                              prefixIcon: Icon(Icons.search, color: Color(0xFF6A11CB)),
                              suffixIcon: searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey),
                                    onPressed: _clearSearch,
                                  ) 
                                : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                            onChanged: (query) {
                              setState(() {
                                searchQuery = query.toLowerCase();
                              });
                            },
                          ),
                          SizedBox(height: 8),
                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categories.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FilterChip(
                                    selectedColor: Color(0xFF6A11CB).withOpacity(0.2),
                                    checkmarkColor: Color(0xFF6A11CB),
                                    label: Text(category),
                                    selected: _filterCategory == category,
                                    onSelected: (selected) {
                                      setState(() {
                                        _filterCategory = category;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  Text(
                    'Popular Teachers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          // Search Results
          _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // Determine which collection to query based on filter
    String collectionName = 'teachers'; // Default
    if (_filterCategory == "Classrooms") {
      collectionName = 'classrooms';
    } else if (_filterCategory == "Subjects") {
      collectionName = 'subjects';
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(collectionName).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return SliverToBoxAdapter(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
                ),
              ),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyState(),
            );
          }

          // Filter results based on search query
          var results = snapshot.data!.docs.where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            if (collectionName == 'teachers') {
              return searchQuery.isEmpty || 
                     data['name']?.toString().toLowerCase().contains(searchQuery) == true ||
                     data['subject']?.toString().toLowerCase().contains(searchQuery) == true;
            } else if (collectionName == 'classrooms') {
              return searchQuery.isEmpty ||
                     data['name']?.toString().toLowerCase().contains(searchQuery) == true ||
                     data['description']?.toString().toLowerCase().contains(searchQuery) == true;
            } else {
              return searchQuery.isEmpty ||
                     data['name']?.toString().toLowerCase().contains(searchQuery) == true;
            }
          }).toList();
          
          if (results.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyState(),
            );
          }
          
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var item = results[index].data() as Map<String, dynamic>;
                
                if (collectionName == 'teachers') {
                  return _buildTeacherCard(item);
                } else if (collectionName == 'classrooms') {
                  return _buildClassroomCard(item);
                } else {
                  return _buildSubjectCard(item);
                }
              },
              childCount: results.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 40),
        Icon(
          Icons.search_off_rounded,
          size: 70,
          color: Colors.grey[400],
        ),
        SizedBox(height: 16),
        Text(
          searchQuery.isEmpty 
              ? 'No items available' 
              : 'No results found for "$searchQuery"',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          searchQuery.isEmpty 
              ? 'Please check back later' 
              : 'Try a different search term or category',
          style: TextStyle(
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to teacher details
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFF6A11CB).withOpacity(0.2),
                child: Text(
                  (teacher['name'] ?? 'T').substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
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
                      teacher['name'] ?? 'Unknown Teacher',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Subject: ${teacher['subject'] ?? 'Not specified'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          teacher['currentLocation'] ?? 'Location not available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassroomCard(Map<String, dynamic> classroom) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to classroom details
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2575FC).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.class_outlined,
                      color: Color(0xFF2575FC),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      classroom['name'] ?? 'Unnamed Classroom',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      classroom['status'] ?? 'Active',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                classroom['description'] ?? 'No description available',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Teacher: ${classroom['teacher'] ?? 'Unassigned'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${classroom['studentCount'] ?? 0} Students',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to subject details
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getSubjectColor(subject['name'] ?? '').withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSubjectIcon(subject['name'] ?? ''),
                  color: _getSubjectColor(subject['name'] ?? ''),
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject['name'] ?? 'Unknown Subject',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subject['description'] ?? 'No description available',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${subject['courseCount'] ?? 0} Courses',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSubjectColor(String subjectName) {
    switch (subjectName.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Colors.blue;
      case 'science':
      case 'physics':
      case 'chemistry':
      case 'biology':
        return Colors.green;
      case 'history':
      case 'social studies':
        return Colors.amber[700]!;
      case 'english':
      case 'literature':
      case 'language arts':
        return Colors.purple;
      case 'computer science':
      case 'programming':
      case 'coding':
        return Colors.indigo;
      case 'art':
      case 'music':
        return Colors.pink;
      default:
        return Color(0xFF6A11CB);
    }
  }

  IconData _getSubjectIcon(String subjectName) {
    switch (subjectName.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Icons.calculate_outlined;
      case 'science':
      case 'physics':
      case 'chemistry':
        return Icons.science_outlined;
      case 'biology':
        return Icons.biotech_outlined;
      case 'history':
      case 'social studies':
        return Icons.history_edu_outlined;
      case 'english':
      case 'literature':
      case 'language arts':
        return Icons.menu_book_outlined;
      case 'computer science':
      case 'programming':
      case 'coding':
        return Icons.computer_outlined;
      case 'art':
        return Icons.palette_outlined;
      case 'music':
        return Icons.music_note_outlined;
      default:
        return Icons.school_outlined;
    }
  }
}