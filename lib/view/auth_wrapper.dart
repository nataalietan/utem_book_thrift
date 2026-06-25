import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'welcome_page.dart';
import 'browse_page.dart';
import 'admin_home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    
    if (user != null) {
      final role = user.userMetadata?['role'] as String?;
      if (role == 'Admin') {
        return const AdminHomePage();
      } else {
        return const BrowsePage();
      }
    }
    
    return const WelcomePage();
  }
}
