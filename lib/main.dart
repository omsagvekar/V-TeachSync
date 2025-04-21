import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/registration_screen.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'admin/admin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      setState(() {
        _isFirebaseInitialized = true;
      });
    } catch (e) {
      print("Firebase initialization failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'V Teach Sync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryColor: Color(0xFF6A11CB),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Color(0xFF2575FC),
        ),
      ),
      home: _isFirebaseInitialized ? AuthWrapper() : SplashScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(); // Show splash screen while waiting
        }

        if (snapshot.hasData) {
          User? user = snapshot.data;

          // Fetch user role from Firestore to check if the user is admin or not
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return SplashScreen(); // Show splash screen instead of just a loading indicator
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${userSnapshot.error}')),
                );
              }

              if (userSnapshot.data?.exists == true) {
                var userData = userSnapshot.data?.data() as Map<String, dynamic>;
                bool isAdmin = userData['role'] == 'Admin';

                // Navigate to the AdminScreen if the user is an admin, otherwise navigate to HomeScreen
                if (isAdmin) {
                  return AdminPanel(); // Admin user
                } else {
                  return HomeScreen(); // Regular user
                }
              } else {
                return RegistrationPage(); // If no user data is found, show registration
              }
            },
          );
        }

        return RegistrationPage(); // User is not signed in
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/splash_screen.jpg', // Replace with your image path
                width: 80, // Set the width of the image
                height: 80, // Set the height of the image
                fit: BoxFit.contain, // Make sure it scales properly
              ),
              SizedBox(height: 20),
              Text(
                'V Teach Sync',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}