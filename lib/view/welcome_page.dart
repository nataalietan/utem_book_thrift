import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_signup_page.dart';
import 'browse_page.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final ScrollController _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: _buildTopNavBar(context, isDesktop),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(context, isDesktop),
            _buildFeaturesSection(isDesktop),
            _buildHowItWorksSection(isDesktop),
            _buildContactSection(isDesktop),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0, vertical: 10.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo & Brand (Clickable to scroll to top)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 60, errorBuilder: (c, e, s) => const Icon(Icons.menu_book, color: Color(0xFF0038FF))),
                  ],
                ),
              ),
            ),
            
            // Desktop Links
            if (isDesktop)
              Row(
                children: [
                  _navLink('Home', () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
                  _navLink('Browse', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BrowsePage()))),
                  _navLink('Services', () => _scrollTo(_servicesKey)),
                  _navLink('How it Works', () => _scrollTo(_howItWorksKey)),
                  _navLink('Contact', () => _scrollTo(_contactKey)),
                ],
              ),
            
            // Login Button
            StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                if (AuthService().currentUser == null) {
                  return ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginSignupPage()),
                      );
                    },
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Login / Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF023E8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  );
                }
                return const SizedBox.shrink(); // Hide if logged in
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          title,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87, // Neutral dark fallback before image loads
        image: DecorationImage(
          image: const AssetImage('assets/images/hero_bg.png'),
          fit: BoxFit.cover,
          alignment: const Alignment(0.0, 0.1), // Shifts the image down
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 24.0,
        vertical: isDesktop ? 100.0 : 60.0,
      ),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Welcome to UTeM Book Thrift!',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Buy and sell easily. Your campus\nmarketplace for preloved academic textbooks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BrowsePage()));
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Browse Textbooks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF023E8A),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_howItWorksKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        _howItWorksKey.currentContext!,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('How it Works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(bool isDesktop) {
    return Container(
      key: _servicesKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 24.0,
        vertical: 80.0,
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AnimatedFeatureCard(icon: Icons.search, bgColor: Colors.blue.shade50, iconColor: Colors.blue, title: 'Easy to Find', desc: 'Browse thousands of preloved textbooks listed directly by the campus community.')),
                const SizedBox(width: 40),
                Expanded(child: AnimatedFeatureCard(icon: Icons.attach_money, bgColor: Colors.green.shade50, iconColor: Colors.green, title: 'Best Prices', desc: 'Save money on academic materials without compromising on quality.')),
                const SizedBox(width: 40),
                Expanded(child: AnimatedFeatureCard(icon: Icons.local_shipping_outlined, bgColor: Colors.purple.shade50, iconColor: Colors.purple, title: 'Quick Pickup', desc: 'Pay securely online and collect your books instantly at the campus bookstore.')),
              ],
            )
          : Column(
              children: [
                AnimatedFeatureCard(icon: Icons.search, bgColor: Colors.blue.shade50, iconColor: Colors.blue, title: 'Easy to Find', desc: 'Browse thousands of preloved textbooks listed directly by the campus community.'),
                const SizedBox(height: 40),
                AnimatedFeatureCard(icon: Icons.attach_money, bgColor: Colors.green.shade50, iconColor: Colors.green, title: 'Best Prices', desc: 'Save money on academic materials without compromising on quality.'),
                const SizedBox(height: 40),
                AnimatedFeatureCard(icon: Icons.local_shipping_outlined, bgColor: Colors.purple.shade50, iconColor: Colors.purple, title: 'Quick Pickup', desc: 'Pay securely online and collect your books instantly at the campus bookstore.'),
              ],
            ),
    );
  }

  Widget _buildHowItWorksSection(bool isDesktop) {
    return Container(
      key: _howItWorksKey,
      width: double.infinity,
      color: const Color(0xFFF9F9F9),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 24.0,
        vertical: 80.0,
      ),
      child: Column(
        children: [
          const Text('How UTeM Book Thrift Works', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 60),
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStepCard('Step 1', 'Secure Login', 'Login with your student or staff email for verified access.', Icons.lock_outline, Colors.teal.shade50, Colors.teal)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildStepCard('Step 2', 'List & Drop Off', 'Post your textbooks online. Once approved, drop them off at the bookstore to receive your payment.', Icons.inventory_2_outlined, Colors.indigo.shade50, Colors.indigo)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildStepCard('Step 3', 'Browse & Buy', 'Find the academic materials you need online.', Icons.shopping_bag_outlined, Colors.orange.shade50, Colors.orange)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildStepCard('Step 4', 'Collect & Read', 'Pick up your purchased books at the store and dive into your materials.', Icons.school_outlined, Colors.red.shade50, Colors.red)),
                  ],
                )
              : Column(
                  children: [
                    _buildStepCard('Step 1', 'Secure Login', 'Login with your student or staff email for verified access.', Icons.lock_outline, Colors.teal.shade50, Colors.teal),
                    const SizedBox(height: 32),
                    _buildStepCard('Step 2', 'List & Drop Off', 'Post your textbooks online. Once approved, drop them off at the bookstore to receive your payment.', Icons.inventory_2_outlined, Colors.indigo.shade50, Colors.indigo),
                    const SizedBox(height: 32),
                    _buildStepCard('Step 3', 'Browse & Buy', 'Find the academic materials you need online.', Icons.shopping_bag_outlined, Colors.orange.shade50, Colors.orange),
                    const SizedBox(height: 32),
                    _buildStepCard('Step 4', 'Collect & Read', 'Pick up your purchased books at the store and dive into your materials.', Icons.school_outlined, Colors.red.shade50, Colors.red),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, String desc, IconData icon, Color bgColor, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: 16),
        Text('$step: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: const Center(
        child: Text(
          '© 2026 UTeM Book Thrift. All rights reserved.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildContactSection(bool isDesktop) {
    return Container(
      key: _contactKey,
      width: double.infinity,
      color: const Color(0xFFF0F4F8), // Soft blue-grey background matching your screenshot
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 24.0,
        vertical: 80.0,
      ),
      child: Column(
        children: [
          const Text('Contact', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          const Text(
            'Feel free to reach out to us with any inquiries, feedback, or support.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 60),
          _buildContactCard(isDesktop),
        ],
      ),
    );
  }

  Widget _buildContactCard(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isDesktop
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: _buildContactSidebar()),
                    Expanded(flex: 3, child: _buildNewContactForm()),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildContactSidebar(),
                  _buildNewContactForm(),
                ],
              ),
      ),
    );
  }

  Widget _buildContactSidebar() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        color: Color(0xFF023E8A), // Deep professional blue
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Reach out to us directly for any academic material queries or support.', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 40),
          _buildSidebarInfoRow(Icons.phone, '06-1926280\n(UTeM Bookstore)'),
          const SizedBox(height: 24),
          _buildSidebarInfoRow(Icons.mail, 'bookthrift@utem.edu.my'),
          const SizedBox(height: 24),
          _buildSidebarInfoRow(Icons.location_on, 'UTeM Bookstore,\nUniversiti Teknikal Malaysia Melaka\nHang Tuah Jaya, 76100\nDurian Tunggal, Melaka.'),
          const SizedBox(height: 24),
          _buildSidebarInfoRow(Icons.access_time, 'Mon - Fri: 8:00 AM - 5:00 PM\nBreak (Mon - Thu): 1:00 PM - 2:00 PM\nBreak (Fri): 12:15 PM - 2:45 PM'),
        ],
      ),
    );
  }

  Widget _buildSidebarInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
      ],
    );
  }

  Widget _buildNewContactForm() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildUnderlineTextField('Your Name', 'e.g. John Doe', controller: _nameController)),
              const SizedBox(width: 32),
              Expanded(child: _buildUnderlineTextField('Your Email', 'e.g. example@utem.edu.my', controller: _emailController)),
            ],
          ),
          const SizedBox(height: 32),
          _buildUnderlineTextField('Your Subject', 'e.g. Question about drop-off or pickup', controller: _subjectController),
          const SizedBox(height: 32),
          _buildUnderlineTextField('Message', 'Write your message here...', maxLines: 4, controller: _messageController),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              final email = _emailController.text.trim();
              final subject = _subjectController.text.trim();
              final message = _messageController.text.trim();

              if (name.isEmpty || email.isEmpty || message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in your name, email, and message.')));
                return;
              }

              if (!email.endsWith('@student.utem.edu.my') && !email.endsWith('@utem.edu.my')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please use a valid UTeM email address (@student.utem.edu.my or @utem.edu.my).')));
                return;
              }

              // Show loading simulation
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              // Simulate network delay
              await Future.delayed(const Duration(seconds: 1));

              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                _nameController.clear();
                _emailController.clear();
                _subjectController.clear();
                _messageController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent successfully! We will get back to you soon.')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF023E8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlineTextField(String label, String hint, {int maxLines = 1, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF023E8A))),
          ),
        ),
      ],
    );
  }
}

class AnimatedFeatureCard extends StatefulWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final String desc;

  const AnimatedFeatureCard({
    super.key,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  @override
  State<AnimatedFeatureCard> createState() => _AnimatedFeatureCardState();
}

class _AnimatedFeatureCardState extends State<AnimatedFeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.bgColor,
                shape: BoxShape.circle,
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.iconColor.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        )
                      ]
                    : [],
              ),
              child: Icon(widget.icon, size: 36, color: widget.iconColor),
            ),
            const SizedBox(height: 24),
            Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(widget.desc, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
