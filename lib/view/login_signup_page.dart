import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'admin_home_page.dart';
import 'browse_page.dart';
import 'signup_success_page.dart';

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  bool isLogin = true; // Toggle state

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  String? selectedRole;
  String? _selectedFaculty;
  String? _selectedStudyLevel;
  String? _selectedGender;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- LOGIC: LOGIN ---
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    setState(() => _isLoading = true);

    final _authService = AuthService();

    try {
      final AuthResponse res = await _authService.signIn(
        email: email,
        password: password,
      );

      if (res.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Successful!'), behavior: SnackBarBehavior.floating));
        
        final role = res.user?.userMetadata?['role'] ?? 'student';
        
        if (role == 'Admin' || role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminHomePage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrowsePage()));
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        String errorMessage = error.message;
        if (errorMessage == 'Invalid login credentials') {
          errorMessage = 'Incorrect email or password. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), behavior: SnackBarBehavior.floating));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: SIGN UP ---
  Future<void> _handleSignUp() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }
    
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields')));
      return;
    }

    // Email Validation based on Role
    if (selectedRole == 'Student') {
      if (!email.endsWith('@student.utem.edu.my')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Students must use @student.utem.edu.my email')));
        return;
      }
    } else if (selectedRole == 'Staff') {
      final staffRegex = RegExp(r'^\d{5}@utem\.edu\.my$');
      if (!staffRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff email must be 5 digits followed by @utem.edu.my')));
        return;
      }
    }

    setState(() => _isLoading = true);

    final _authService = AuthService();
    final _userService = UserService();

    try {
      final AuthResponse res = await _authService.signUp(
        email: email,
        password: password,
        data: {
          'fullName': name,
          'role': selectedRole,
          if (_selectedFaculty != null) 'faculty': _selectedFaculty,
          if (selectedRole == 'Student' && _selectedStudyLevel != null) 'study_level': _selectedStudyLevel,
          if (_selectedGender != null) 'gender': _selectedGender,
        },
      );
      
      if (res.user != null) {
        // Automatically insert the new user into the public USER table!
        try {
          final newUser = UserModel(
            userID: res.user!.id,
            email: email,
            fullName: name,
            role: selectedRole!,
            faculty: _selectedFaculty,
            studyLevel: selectedRole == 'Student' ? _selectedStudyLevel : null,
            gender: _selectedGender,
          );
          await _userService.upsertUser(newUser);
        } catch (dbError) {
          debugPrint('Could not insert into USER table: $dbError');
        }
        if (res.session == null) {
          // Email confirmation is ON
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) {
                StreamSubscription<AuthState>? subscription;
                subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
                  final AuthChangeEvent event = data.event;
                  if (event == AuthChangeEvent.signedIn) {
                    subscription?.cancel();
                    Navigator.of(dialogContext).pop(); 
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignupSuccessPage(role: selectedRole!)));
                  }
                });

                return AlertDialog(
                  title: const Text('Check your email'),
                  content: const Text('We have sent a confirmation link to your email. Please click the link to verify your account. Your account will be created once it is verified.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        subscription?.cancel();
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Cancel'),
                    )
                  ],
                );
              }
            );
          }
        } else {
          // Email confirmation is OFF (Development Mode)
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignupSuccessPage(role: selectedRole!)));
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          // Split screen layout
          Row(
            children: [
              // Left Side: Image (Only visible on Desktop)
              if (isDesktop)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      image: DecorationImage(
                        image: AssetImage('assets/images/auth_bg.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.4), // Dark overlay for text readability
                      padding: const EdgeInsets.all(60.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start, // Moved to the top
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 100), // Give it some breathing room from the very top
                          Text(
                            'UTeM Book Thrift',
                            style: GoogleFonts.montserrat(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Buy and sell academic textbooks with students or staff from UTeM. Start finding great deals on textbooks!',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
              // Right Side: Auth Card Area
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Toggle (Login / Sign Up)
                              _buildToggle(),
                              
                              const SizedBox(height: 32),
                              
                              // Dynamic Title
                              Text(
                                isLogin ? 'Welcome Back' : 'Create Account',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isLogin ? 'Enter your credentials to access your account' : 'Join the campus marketplace community',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Sign Up Only Fields
                              if (!isLogin) ...[
                                _buildTextField('Full Name', hint: 'John Doe', icon: Icons.person_outline, controller: _nameController),
                                const SizedBox(height: 16),
                                _buildRoleDropdown(),
                                const SizedBox(height: 16),
                                if (selectedRole == 'Student') ...[
                                  _buildFacultyDropdown(),
                                  const SizedBox(height: 16),
                                  _buildStudyLevelDropdown(),
                                  const SizedBox(height: 16),
                                  _buildGenderDropdown(),
                                  const SizedBox(height: 16),
                                ],
                                if (selectedRole == 'Staff') ...[
                                  _buildFacultyDropdown(),
                                  const SizedBox(height: 16),
                                  _buildGenderDropdown(),
                                  const SizedBox(height: 16),
                                ],
                              ],
                              
                              // Shared Fields
                              _buildTextField(
                                'Email', 
                                hint: _getEmailHint(), 
                                icon: Icons.mail_outline, 
                                controller: _emailController
                              ),
                              const SizedBox(height: 16),

                              _buildTextField('Password', hint: '••••••••', icon: Icons.lock_outline, obscureText: true, controller: _passwordController),
                              
                              const SizedBox(height: 32),

                              // Submit Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : (isLogin ? _handleLogin : _handleSignUp),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF023E8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        isLogin ? 'Sign In' : 'Create Account',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Back Button
          Positioned(
            top: 16,
            left: isDesktop ? null : 16,
            right: isDesktop ? 16 : null, // If desktop, put it top right on the white side to be visible
            child: IconButton(
              icon: Icon(Icons.close, color: isDesktop ? Colors.black54 : Colors.black87),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isLogin = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontWeight: isLogin ? FontWeight.bold : FontWeight.w500,
                      color: isLogin ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isLogin = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: !isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontWeight: !isLogin ? FontWeight.bold : FontWeight.w500,
                      color: !isLogin ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        prefixIcon: const Icon(Icons.badge_outlined, color: Colors.black38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF023E8A)),
        ),
      ),
      hint: const Text('Select Your Role', style: TextStyle(color: Colors.black54, fontSize: 14)),
      value: selectedRole,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
      items: ['Student', 'Staff'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          selectedRole = newValue;
          if (newValue == 'Student') {
            _selectedFaculty = null;
          } else {
            _selectedFaculty = null;
            _selectedStudyLevel = null;
          }
        });
      },
    );
  }

  Widget _buildFacultyDropdown() {
    List<String> options = selectedRole == 'Staff' 
        ? ['FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'SPAB', 'IPTK']
        : ['FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'IPTK'];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        prefixIcon: const Icon(Icons.school_outlined, color: Colors.black38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF023E8A))),
      ),
      hint: const Text('Select Faculty', style: TextStyle(color: Colors.black54, fontSize: 14)),
      value: _selectedFaculty,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
      items: options.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (newValue) => setState(() => _selectedFaculty = newValue),
    );
  }

  Widget _buildStudyLevelDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        prefixIcon: const Icon(Icons.menu_book_outlined, color: Colors.black38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF023E8A))),
      ),
      hint: const Text('Study Level', style: TextStyle(color: Colors.black54, fontSize: 14)),
      value: _selectedStudyLevel,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
      items: ['Diploma', 'Degree', 'Master\'s', 'PhD'].map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (newValue) => setState(() => _selectedStudyLevel = newValue),
    );
  }


  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        prefixIcon: const Icon(Icons.person_pin_outlined, color: Colors.black38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF023E8A))),
      ),
      hint: const Text('Gender', style: TextStyle(color: Colors.black54, fontSize: 14)),
      value: _selectedGender,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
      items: ['Male', 'Female'].map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (newValue) => setState(() => _selectedGender = newValue),
    );
  }

  Widget _buildTextField(String label, {required String hint, bool obscureText = false, required TextEditingController controller, required IconData icon}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        prefixIcon: Icon(icon, color: Colors.black38, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF023E8A)),
        ),
      ),
    );
  }

  String _getEmailHint() {
    if (isLogin) return 'example@utem.edu.my';
    if (selectedRole == 'Student') return 'matricno@student.utem.edu.my';
    if (selectedRole == 'Staff') return 'staffno@utem.edu.my';
    return 'example@utem.edu.my';
  }
}
