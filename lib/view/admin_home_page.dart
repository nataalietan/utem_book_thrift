import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/textbook_service.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../models/textbook_model.dart';
import '../models/order_model.dart';
import 'textbook_details_page.dart';
import '../models/user_model.dart';
import 'welcome_page.dart';
import 'add_listing_page.dart';
import 'edit_listing_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'widgets/notification_badge.dart';
import '../services/notification_service.dart';
import '../services/pdf_report_service.dart';

class AdminHomePage extends StatefulWidget {
  final int? initialIndex;
  const AdminHomePage({super.key, this.initialIndex});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  List<TextbookModel> inventoryListings = [];
  List<OrderModel> _orders = [];

  // Profile Form Controllers
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dropOffPinController = TextEditingController();
  String _dropOffSearchQuery = '';
  bool _isLoading = false;
  String _initials = 'A';
  bool _isAddingListing = false;
  TextbookModel? _editingTextbook;
  
  String _orderStatusFilter = 'Action Required';
  int _ordersCurrentPage = 1;
  static const int _ordersPerPage = 10;
  String _pickupStatusFilter = 'Pending';
  String _inventoryTab = 'All';
  String _approvalsTab = 'All';
  DateTimeRange? _selectedDateRange;
  int _touchedPieIndex = -1;
  String _analyticsPeriod = 'Today';
  int _periodOffset = 0;

  final _authService = AuthService();
  final _textbookService = TextbookService();
  final _orderService = OrderService();
  final _userService = UserService();
  
  final ScrollController _horizontalScrollController = ScrollController();
  final _orderSearchController = TextEditingController();

  String get _userName {
    final user = _authService.currentUser;
    return user?.userMetadata?['fullName'] ?? 'Admin Worker';
  }

  String get _userEmail {
    return _authService.currentUser?.email ?? 'admin@utem.edu.my';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
    }
    _nameController.text = _userName;
    _calculateInitials();
    _fetchInventory();
    _fetchOrders();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInventory() async {
    try {
      final data = await _textbookService.fetchAllBooks();
        setState(() {
          inventoryListings = data;
        });
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final data = await _orderService.fetchAllOrders();
      setState(() {
        _orders = data;
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
  }

  Future<void> _deleteListing(dynamic textbookId) async {
    if (textbookId == null) return;
    try {
      await _textbookService.updateTextbookStatus(textbookId, 'Deleted by Admin');
      _fetchInventory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting listing: $e')));
    }
  }

  Future<void> _updateOrderStatus(dynamic orderId, String newStatus) async {
    if (orderId == null) return;
    try {
      await _orderService.updateOrderStatus(orderId, newStatus);
      _fetchOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order marked as $newStatus')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
    }
  }

  Future<void> _updatePickupStatus(dynamic paymentId, List<dynamic>? itemTextbookIds, String status) async {
    setState(() => _isLoading = true);
    try {
      await _orderService.updatePickupStatus(paymentId, status);
      if (status == 'Picked Up' && itemTextbookIds != null) {
        for (var tbId in itemTextbookIds) {
          await _textbookService.updateTextbookStatus(tbId, 'Picked Up');
        }
      }
      _fetchOrders();
      _fetchInventory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPinVerificationDialog(OrderModel order, dynamic paymentId, List<dynamic>? textbookIds) {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Verify Pickup PIN', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please ask the buyer for their 4-digit Pickup PIN to confirm they are receiving the order.'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: '4-Digit PIN',
                  errorText: errorMessage,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinController.text == order.pickupPin || pinController.text == '0000') { // 0000 as emergency override
                  Navigator.pop(context);
                  await _updateOrderStatus(order.orderID, 'Completed');
                  await _updatePickupStatus(paymentId, textbookIds, 'Picked Up');
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order picked up & completed!')));
                } else {
                  setState(() => errorMessage = 'Invalid PIN. Please try again.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
              child: const Text('Verify & Complete'),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateInitials() {
    final parts = _userName.split(' ');
    if (parts.length > 1) {
      _initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      _initials = parts[0].substring(0, 1).toUpperCase();
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (route) => false,
      );
    }
  }

  Future<void> _handleUpdateProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.updateUserMetadata({
          'fullName': newName,
        });

        if (_passwordController.text.isNotEmpty) {
           await _authService.updatePassword(_passwordController.text);
        }

        try {
          final userRole = user.userMetadata?['role'] ?? 'Admin';
          final userModel = UserModel(
            userID: user.id,
            email: user.email ?? '',
            fullName: newName,
            role: userRole,
          );
          await _userService.upsertUser(userModel);
        } catch (e) {
          debugPrint('Error updating public table: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
          _passwordController.clear();
          setState(() {
            _calculateInitials();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Soft modern background for analytics
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isDesktop) _buildMobileHeader(),
                Expanded(
                  child: _isAddingListing
                      ? AddListingPage(onBack: () {
                          setState(() => _isAddingListing = false);
                          _fetchInventory();
                        })
                      : _editingTextbook != null
                          ? EditListingPage(
                              title: 'Textbook Details',
                              extraAction: _editingTextbook!.status == 'Pending Drop-off'
                                  ? ElevatedButton.icon(
                                      onPressed: () => _showReceiveDialog(_editingTextbook!),
                                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                                      label: const Text(
                                        'Verify PIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF023E8A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                    )
                                  : null,
                              textbook: _editingTextbook!,
                              isAdminEdit: true,
                              onBack: () {
                                setState(() => _editingTextbook = null);
                                _fetchInventory();
                              },
                            )
                          : IndexedStack(
                              index: _selectedIndex,
                              children: [
                                _buildDashboardView(isDesktop),
                                _buildDropOffView(isDesktop),
                                _buildApprovalsView(isDesktop),
                                _buildInventoryView(isDesktop),
                                _buildOrdersManagementView(isDesktop),
                                _buildProfileView(isDesktop),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: null,
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(),
    );
  }

  // --- Layout Components ---

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/logo.png', height: 60, errorBuilder: (c, e, s) => const Icon(Icons.menu_book, color: Color(0xFF023E8A), size: 40)),
                const NotificationBadge(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Navigation Links
          _buildSidebarItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, 0),
          _buildSidebarItem('Book Drop-off', Icons.move_to_inbox_outlined, Icons.move_to_inbox, 1),
          _buildSidebarItem('Approvals', Icons.fact_check_outlined, Icons.fact_check, 2),
          _buildSidebarItem('All Listings', Icons.inventory_2_outlined, Icons.inventory_2, 3),
          _buildSidebarItem('Orders', Icons.receipt_long_outlined, Icons.receipt_long, 4),
          _buildSidebarItem('Profile', Icons.person_outline, Icons.person, 5),
          
          const Spacer(),
          
          // Logout
          const Divider(height: 1),
          InkWell(
            onTap: _handleLogout,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  SizedBox(width: 16),
                  Text('Log out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData iconOutlined, IconData iconFilled, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
        _isAddingListing = false;
        _editingTextbook = null;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF023E8A).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(isSelected ? iconFilled : iconOutlined, color: isSelected ? const Color(0xFF023E8A) : Colors.black54, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF023E8A) : Colors.black87,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/images/logo.png', height: 60, errorBuilder: (c, e, s) => const Icon(Icons.menu_book, color: Color(0xFF023E8A))),
            Row(
              children: [
                const NotificationBadge(),
                IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _handleLogout),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() {
        _selectedIndex = index;
        _isAddingListing = false;
        _editingTextbook = null;
      }),
      selectedItemColor: const Color(0xFF023E8A),
      unselectedItemColor: Colors.black54,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.move_to_inbox_outlined), activeIcon: Icon(Icons.move_to_inbox), label: 'Drop-off'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), activeIcon: Icon(Icons.fact_check), label: 'Approvals'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Listings'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  // --- Views ---

  Widget _buildDashboardView(bool isDesktop) {
    // ----------------------------------------------------
    // REAL DATA CALCULATIONS
    // ----------------------------------------------------
    final now = DateTime.now();
    DateTime? startFilter;
    DateTime? endFilter;
    String periodLabel = '';

    if (_analyticsPeriod == 'Today') {
      final targetDate = now.add(Duration(days: _periodOffset));
      startFilter = DateTime(targetDate.year, targetDate.month, targetDate.day);
      endFilter = startFilter.add(const Duration(days: 1));
      
      final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
      periodLabel = isToday ? 'Today' : '${targetDate.day}/${targetDate.month}/${targetDate.year}';
    } else if (_analyticsPeriod == 'Week') {
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      final targetMonday = currentMonday.add(Duration(days: 7 * _periodOffset));
      startFilter = DateTime(targetMonday.year, targetMonday.month, targetMonday.day);
      endFilter = startFilter.add(const Duration(days: 7));
      
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final endLabelDate = endFilter.subtract(const Duration(days: 1));
      periodLabel = '${months[startFilter.month - 1]} ${startFilter.day} - ${months[endLabelDate.month - 1]} ${endLabelDate.day}';
    } else if (_analyticsPeriod == 'Month') {
      final targetMonth = DateTime(now.year, now.month + _periodOffset, 1);
      startFilter = targetMonth;
      endFilter = DateTime(targetMonth.year, targetMonth.month + 1, 1);
      
      const fullMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      periodLabel = '${fullMonths[startFilter.month - 1]} ${startFilter.year}';
    } else if (_analyticsPeriod == 'Year') {
      final targetYear = DateTime(now.year + _periodOffset, 1, 1);
      startFilter = targetYear;
      endFilter = DateTime(targetYear.year + 1, 1, 1);
      periodLabel = '${startFilter.year}';
    } else {
      periodLabel = 'All Time';
    }

    final filteredOrders = _orders.where((o) {
      if (startFilter == null || endFilter == null) return true;
      if (o.orderedAt.isEmpty) return false;
      final date = DateTime.tryParse(o.orderedAt);
      if (date == null) return false;
      
      return date.isAfter(startFilter.subtract(const Duration(milliseconds: 1))) && date.isBefore(endFilter);
    }).toList();

    final validOrders = filteredOrders.where((o) => o.status != 'Cancelled').toList();
    
    // 1. Total Marketplace Volume
    final totalRevenue = validOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
    
    int booksSold = 0;
    for (var order in validOrders) {
      if (order.status == 'Completed' && order.items != null) {
        booksSold += order.items!.length;
      }
    }

    // 3. New Listings
    final validListings = inventoryListings.where((l) {
      if (l.status == 'Rejected' || l.status == 'Removed') return false;
      if (startFilter == null || endFilter == null) return true;
      if (l.createdAt.isEmpty) return false;
      final date = DateTime.tryParse(l.createdAt);
      if (date == null) return false;
      return date.isAfter(startFilter.subtract(const Duration(milliseconds: 1))) && date.isBefore(endFilter);
    }).toList();
    
    int newListingsCount = validListings.length;
    // ----------------------------------------------------

    return SingleChildScrollView(
      key: const PageStorageKey<String>('AdminDashboardScrollKey'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome Back, ${_userName.split(' ').first}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                const Text('Monitor marketplace performance and textbook analytics', style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Wrap(
                        spacing: 0,
                        runSpacing: 4,
                        children: ['Today', 'Week', 'Month', 'Year', 'All Time'].map((p) {
                          final isSelected = _analyticsPeriod == p;
                          return GestureDetector(
                            onTap: () => setState(() { _analyticsPeriod = p; _periodOffset = 0; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
                              ),
                              child: Text(p, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black87 : Colors.black54)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (_analyticsPeriod != 'All Time')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: () => setState(() => _periodOffset--),
                            splashRadius: 20,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          const SizedBox(width: 8),
                          Text(periodLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: _periodOffset < 0 ? () => setState(() => _periodOffset++) : null,
                            splashRadius: 20,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            color: _periodOffset < 0 ? Colors.black87 : Colors.black26,
                          ),
                        ],
                      ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final topDomainsList = _getTopDomains(validOrders);
                        String topDomainsString = topDomainsList.map((e) => e.key).join(', ');
                        if (topDomainsString.isEmpty) topDomainsString = 'None';
                        
                        await PdfReportService.downloadAnalyticsReport(
                          periodLabel: periodLabel,
                          totalSalesVolume: totalRevenue,
                          topDomains: topDomainsString,
                          booksSold: booksSold,
                          orders: validOrders,
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF023E8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Top Summary Cards
            isDesktop ? Row(
              children: [
                Expanded(child: _buildAnalyticsCard('Total Sales Volume', 'RM ${totalRevenue.toStringAsFixed(2)}', Icons.attach_money, const Color(0xFF023E8A), '')),
                const SizedBox(width: 24),
                Expanded(child: _buildAnalyticsCard('Books Sold', '$booksSold', Icons.menu_book, Colors.green, '')),
                const SizedBox(width: 24),
                Expanded(child: _buildAnalyticsCard('New Listings', '$newListingsCount', Icons.add_box_outlined, Colors.orange, '')),
              ],
            ) : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildAnalyticsCard('Total Sales Volume', 'RM ${totalRevenue.toStringAsFixed(0)}', Icons.attach_money, const Color(0xFF023E8A), '')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildAnalyticsCard('Books Sold', '$booksSold', Icons.menu_book, Colors.green, '')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAnalyticsCard('New Listings', '$newListingsCount', Icons.add_box_outlined, Colors.orange, ''),
              ],
            ),
            const SizedBox(height: 32),

            // Charts
            isDesktop ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildBarChartCard(filteredOrders)),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildPieChartCard(filteredOrders)),
              ],
            ) : Column(
              children: [
                _buildBarChartCard(filteredOrders),
                const SizedBox(height: 24),
                _buildPieChartCard(filteredOrders),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(trend, style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildBarChartCard(List<OrderModel> filteredOrders) {
    int placedCount = filteredOrders.where((o) => o.status == 'Placed').length;
    int completedCount = filteredOrders.where((o) => o.status == 'Completed').length;
    int cancelRequestedCount = filteredOrders.where((o) => o.status == 'Cancel Requested').length;
    int cancelledCount = filteredOrders.where((o) => o.status == 'Cancelled').length;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Status Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: false,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.round().toString(),
                        TextStyle(color: rod.color, fontWeight: FontWeight.bold, fontSize: 16),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54);
                        switch (value.toInt()) {
                          case 0: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Placed', style: style));
                          case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Completed', style: style));
                          case 2: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Cancel Req.', style: style));
                          case 3: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Cancelled', style: style));
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: placedCount.toDouble(), color: const Color(0xFF3B82F6), width: 32, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 10, color: Colors.grey.shade100))], showingTooltipIndicators: [0]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: completedCount.toDouble(), color: const Color(0xFF10B981), width: 32, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 10, color: Colors.grey.shade100))], showingTooltipIndicators: [0]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: cancelRequestedCount.toDouble(), color: const Color(0xFFF59E0B), width: 32, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 10, color: Colors.grey.shade100))], showingTooltipIndicators: [0]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: cancelledCount.toDouble(), color: const Color(0xFFEF4444), width: 32, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 10, color: Colors.grey.shade100))], showingTooltipIndicators: [0]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _getTopDomains(List<OrderModel> ordersList) {
    final completedOrders = ordersList.where((o) => o.status == 'Completed').toList();
    final Map<String, int> domainCounts = {};
    for (var order in completedOrders) {
      if (order.items != null) {
        for (var item in order.items!) {
          final domain = item.textbook?.domain ?? 'Other';
          if (domain.isNotEmpty) {
            domainCounts[domain] = (domainCounts[domain] ?? 0) + 1;
          }
        }
      }
    }
    final sortedDomains = domainCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sortedDomains.take(3).toList();
  }

  Widget _buildPieChartCard(List<OrderModel> filteredOrders) {
    final topDomains = _getTopDomains(filteredOrders);
    final colors = [const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
    
    final totalSold = topDomains.fold(0, (sum, e) => sum + e.value);

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Selling Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 32),
          Expanded(
            child: topDomains.isEmpty 
              ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.black38)))
              : Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: topDomains.asMap().entries.map((entry) {
                      final index = entry.key;
                      final domain = entry.value;
                      final percentage = (domain.value / totalSold) * 100;
                      final isTouched = index == _touchedPieIndex;
                      
                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: domain.value.toDouble(),
                        title: '${percentage.toStringAsFixed(0)}%\n(${domain.value})',
                        radius: isTouched ? 60 : 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$totalSold', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Text('Total Books Sold', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Top Categories', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 16),
          if (topDomains.isNotEmpty)
            Column(
              children: topDomains.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildLegendItem(colors[entry.key % colors.length], '${entry.value.key} (${entry.value.value})'),
                );
              }).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Future<void> _verifyDropOffPin() async {
    final pin = _dropOffPinController.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a PIN code.')));
      return;
    }

    final pendingDropOffs = inventoryListings.where((b) => b.status == 'Pending Drop-off').toList();
    TextbookModel? matchedBook;
    for (var book in pendingDropOffs) {
      if (book.dropOffPin == pin) {
        matchedBook = book;
        break;
      }
    }

    if (matchedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN or no matching pending drop-off found.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _textbookService.updateTextbook(matchedBook.textbookID, {
        'status': 'Pending Edit',
        'sellerEarnings': matchedBook.listingPrice,
      });
      
      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: matchedBook.sellerID,
        title: 'Drop-off Successful!',
        message: 'You have successfully handed over "${matchedBook.title}" and earned RM ${matchedBook.listingPrice.toStringAsFixed(2)}. It will be available on the platform once the admin reviews it.',
        type: 'drop_off_success',
        referenceId: matchedBook.textbookID.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success! ${matchedBook.title} is now Pending Edit.')));
        _dropOffPinController.clear();
        _editingTextbook = null;
      }
      await _fetchInventory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReceiveDialog(TextbookModel book) {
    final pinController = TextEditingController();
    String? errorMessage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Receive Textbook', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter PIN to verify ${book.title} is being dropped off.'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: '4-Digit PIN',
                  errorText: errorMessage,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.black54))
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinController.text.trim() == book.dropOffPin) {
                  Navigator.pop(context);
                  this.setState(() => _isLoading = true);
                  try {
                    await _textbookService.updateTextbook(book.textbookID, {
                      'status': 'Pending Edit',
                      'sellerEarnings': book.listingPrice,
                    });
                    
                    final notificationService = NotificationService();
                    await notificationService.sendNotification(
                      userId: book.sellerID,
                      title: 'Drop-off Successful!',
                      message: 'You have successfully handed over "${book.title}" and earned RM ${book.listingPrice.toStringAsFixed(2)}. It will be available on the platform once the admin reviews it.',
                      type: 'drop_off_success',
                      referenceId: book.textbookID.toString(),
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Success! ${book.title} is now Pending Edit.')));
                      this.setState(() {
                        _editingTextbook = null;
                      });
                    }
                    await _fetchInventory();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  } finally {
                    if (mounted) this.setState(() => _isLoading = false);
                  }
                } else {
                  setState(() => errorMessage = 'Invalid PIN. Please try again.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropOffView(bool isDesktop) {
    final pendingDropOffs = inventoryListings.where((b) => b.status == 'Pending Drop-off').toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Book Drop-off', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          const Text('Search for a textbook title to verify details and drop off.', style: TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 32),
          
          Row(
            children: [
              SizedBox(
                width: isDesktop ? 400 : 250,
                child: TextField(
                  onChanged: (value) => setState(() => _dropOffSearchQuery = value),
                  decoration: const InputDecoration(
                    labelText: 'Search Textbook Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: pendingDropOffs.isEmpty
                ? const Center(child: Text('No books awaiting drop-off.', style: TextStyle(fontSize: 16, color: Colors.black54)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 600 ? 3 : 2));
                      final filteredDropOffs = _dropOffSearchQuery.isEmpty ? pendingDropOffs : pendingDropOffs.where((b) => b.title.toLowerCase().contains(_dropOffSearchQuery.toLowerCase())).toList();
                      
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: filteredDropOffs.length,
                        itemBuilder: (context, index) {
                          return _buildDropOffBookCard(filteredDropOffs[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropOffBookCard(TextbookModel book) {
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        setState(() => _editingTextbook = book);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[200],
                  image: book.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(book.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: book.imageUrl == null ? const Center(child: Icon(Icons.book, size: 50, color: Colors.black26)) : null,
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seller: ${book.seller?.fullName ?? "Unknown"}',
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsView(bool isDesktop) {
    final pendingBooks = inventoryListings.where((b) {
      bool isPending = b.status == 'Pending Approval';
      bool isDelete = b.isDeleteRequested;
      
      if (!isPending && !isDelete) return false;
      
      if (_approvalsTab == 'Pending Approval') return isPending && !isDelete;
      if (_approvalsTab == 'Delete Requests') return isDelete;
      return true; // 'All'
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isDesktop ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pending Approvals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildApprovalsTabButton('All', inventoryListings.where((b) => b.status == 'Pending Approval' || b.isDeleteRequested).length),
                    _buildApprovalsTabButton('Pending Approval', inventoryListings.where((b) => b.status == 'Pending Approval').length),
                    _buildApprovalsTabButton('Delete Requests', inventoryListings.where((b) => b.isDeleteRequested).length),
                  ],
                ),
              ),
            ],
          ) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pending Approvals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildApprovalsTabButton('All', inventoryListings.where((b) => b.status == 'Pending Approval' || b.isDeleteRequested).length),
                      _buildApprovalsTabButton('Pending Approval', inventoryListings.where((b) => b.status == 'Pending Approval').length),
                      _buildApprovalsTabButton('Delete Requests', inventoryListings.where((b) => b.isDeleteRequested).length),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Review textbook listings and delete requests submitted by sellers.', style: TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: pendingBooks.isEmpty
                ? const Center(child: Text('No pending approvals at the moment.', style: TextStyle(fontSize: 16, color: Colors.black54)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 600 ? 3 : 2));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: pendingBooks.length,
                        itemBuilder: (context, index) {
                          return _buildPendingBookCard(pendingBooks[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsTabButton(String label, int count) {
    bool isSelected = _approvalsTab == label;
    return InkWell(
      onTap: () => setState(() => _approvalsTab = label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF023E8A) : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBookCard(TextbookModel book) {
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextbookDetailsPage(textbook: book, showActions: false),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    color: Colors.black12,
                    width: double.infinity,
                    child: book.imageUrl != null
                        ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.menu_book, color: Colors.white, size: 40),
                  ),
                ),
                if (!book.isDeleteRequested)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _editingTextbook = book),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showDeleteDialog(book),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                            child: const Icon(Icons.delete, size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('Proposed Price: RM ${book.listingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A), fontSize: 14)),
                const SizedBox(height: 4),
                Text('Original Price: RM ${book.originalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 12),
                if (book.rejectionReason != null && !book.isDeleteRequested)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Expanded(child: Text('Previously rejected: ${book.rejectionReason}', style: const TextStyle(fontSize: 10, color: Colors.orange))),
                      ],
                    ),
                  ),
                  
                if (book.isDeleteRequested)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            const Text('DELETE REQUEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                          ]
                        ),
                        const SizedBox(height: 2),
                        Text(book.deleteRequestReason ?? 'No reason provided.', style: const TextStyle(fontSize: 10, color: Colors.red)),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => book.isDeleteRequested ? _showRejectDeleteDialog(book) : _showRejectDialog(book),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(book.isDeleteRequested ? 'Reject Delete' : 'Reject', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => book.isDeleteRequested ? _approveDeleteRequest(book) : _approveListing(book),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(book.isDeleteRequested ? 'Approve Delete' : 'Approve', style: const TextStyle(fontSize: 11)),
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

  Future<void> _approveListing(TextbookModel book) async {
    setState(() => _isLoading = true);
    try {
      final String newPin = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
      await _textbookService.updateTextbook(book.textbookID, {
        'status': 'Pending Drop-off',
        'dropOffPin': book.dropOffPin?.isNotEmpty == true ? book.dropOffPin : newPin,
        'rejectionReason': null,
      });
      
      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: book.sellerID,
        title: 'Listing Approved',
        message: 'Your listing "${book.title}" has been approved! Please drop off your textbook.',
        type: 'listing_approved',
        referenceId: book.textbookID.toString(),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing approved successfully!')));
      await _fetchInventory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDeleteRequest(TextbookModel book) async {
    setState(() => _isLoading = true);
    try {
      await _textbookService.updateTextbookStatus(book.textbookID, 'Deleted by Admin');
      await _textbookService.updateTextbook(book.textbookID, {
        'isDeleteRequested': false,
        'deleteRequestReason': null,
      });
      
      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: book.sellerID,
        title: 'Delete Request Approved',
        message: 'Your request to delete "${book.title}" has been approved.',
        type: 'delete_request_approved',
        referenceId: book.textbookID.toString(),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request approved!')));
      await _fetchInventory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectDeleteDialog(TextbookModel book) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Delete Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting the delete request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Reason to delete is not valid.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
                return;
              }
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await _textbookService.updateTextbook(book.textbookID, {
                  'isDeleteRequested': false,
                  'deleteRequestReason': null,
                  'rejectionReason': reason,
                });
                
                final notificationService = NotificationService();
                await notificationService.sendNotification(
                  userId: book.sellerID,
                  title: 'Delete Request Denied',
                  message: 'Your request to delete "${book.title}" was denied. Reason: $reason',
                  type: 'delete_request_rejected',
                  referenceId: book.textbookID.toString(),
                );
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request rejected.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject Delete'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(TextbookModel book) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason or suggest a different price for the seller:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Price is too high, suggest RM 25 instead.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Reason is required')));
                return;
              }
              Navigator.pop(dialogContext);
              
              setState(() => _isLoading = true);
              try {
                await _textbookService.updateTextbook(book.textbookID, {
                  'status': 'Rejected',
                  'rejectionReason': reason,
                });
                
                final notificationService = NotificationService();
                await notificationService.sendNotification(
                  userId: book.sellerID,
                  title: 'Listing Rejected',
                  message: 'Your listing "${book.title}" was rejected. Reason: $reason',
                  type: 'listing_rejected',
                  referenceId: book.textbookID.toString(),
                );
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Listing rejected and feedback sent.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showArchiveDialog(TextbookModel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Listing'),
        content: const Text('Are you sure you want to archive this listing? It will be hidden from buyers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _textbookService.updateTextbook(book.textbookID, {'isArchived': true});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing archived.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(TextbookModel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Listing'),
        content: const Text('Are you sure you want to restore this listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _textbookService.updateTextbook(book.textbookID, {'isArchived': false});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing restored.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showHardDeleteDialog(TextbookModel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing Permanently'),
        content: const Text('Are you sure you want to permanently delete this listing? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _textbookService.deleteTextbook(book.textbookID);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing permanently deleted.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(TextbookModel book) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for deleting this listing:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: book.status == 'Pending Approval' 
                    ? 'e.g. Listing violates our policy.' 
                    : 'e.g. Seller requested removal.',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
                return;
              }
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await _textbookService.updateTextbookStatus(book.textbookID, 'Deleted by Admin');
                await _textbookService.updateTextbook(book.textbookID, {
                  'rejectionReason': reason,
                });
                
                final notificationService = NotificationService();
                await notificationService.sendNotification(
                  userId: book.sellerID,
                  title: 'Listing Deleted',
                  message: 'Your listing "${book.title}" was removed. Reason: $reason',
                  type: 'listing_deleted',
                  referenceId: book.textbookID.toString(),
                );

                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted and feedback sent.')));
                await _fetchInventory();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRejectCancelDialog(OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Order Cancellation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this cancellation request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Reason for cancellation is not valid.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Reason is required')));
                return;
              }
              Navigator.pop(dialogContext); // Close dialog
              
              setState(() => _isLoading = true);
              try {
                await _orderService.rejectOrderCancel(order.orderID, reason, order.buyerID);
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Cancellation rejected and feedback sent.')));
                await _fetchOrders();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  // --- End Approvals View ---

  Widget _buildInventoryView(bool isDesktop) {
    final filteredInventory = inventoryListings.where((book) {
      if (_inventoryTab == 'Archived') return book.isArchived;
      if (book.isArchived) return false;
      if (_inventoryTab == 'Available') return book.status == 'Available';
      if (_inventoryTab == 'Pending Edit') return book.status == 'Pending Edit';
      if (_inventoryTab == 'Sold') return book.status == 'Sold';
      if (_inventoryTab == 'Picked Up') return book.status == 'Picked Up';
      return book.status == 'Available' || book.status == 'Pending Edit' || book.status == 'Sold' || book.status == 'Picked Up';
    }).toList();

    if (filteredInventory.isEmpty && _inventoryTab == 'Available' && inventoryListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 100, color: Colors.black26),
            const SizedBox(height: 24),
            const Text('No Inventory Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            const Text('Tap the Add Listing button to add the first textbook.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      );
    }

    int crossAxisCount = isDesktop ? 4 : 2;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isDesktop ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('All Listings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        _buildInventoryTabButton('All', inventoryListings.where((b) => !b.isArchived && (b.status == 'Available' || b.status == 'Pending Edit' || b.status == 'Sold' || b.status == 'Picked Up')).length),
                        _buildInventoryTabButton('Pending Edit', inventoryListings.where((b) => !b.isArchived && b.status == 'Pending Edit').length),
                        _buildInventoryTabButton('Available', inventoryListings.where((b) => !b.isArchived && b.status == 'Available').length),
                        _buildInventoryTabButton('Sold', inventoryListings.where((b) => !b.isArchived && b.status == 'Sold').length),
                        _buildInventoryTabButton('Picked Up', inventoryListings.where((b) => !b.isArchived && b.status == 'Picked Up').length),
                        _buildInventoryTabButton('Archived', inventoryListings.where((b) => b.isArchived).length),
                    ],
                  ),
                ),
              ],
            ) : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All Listings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          _buildInventoryTabButton('All', inventoryListings.where((b) => !b.isArchived && (b.status == 'Available' || b.status == 'Pending Edit' || b.status == 'Sold' || b.status == 'Picked Up')).length),
                          _buildInventoryTabButton('Pending Edit', inventoryListings.where((b) => !b.isArchived && b.status == 'Pending Edit').length),
                          _buildInventoryTabButton('Available', inventoryListings.where((b) => !b.isArchived && b.status == 'Available').length),
                          _buildInventoryTabButton('Sold', inventoryListings.where((b) => !b.isArchived && b.status == 'Sold').length),
                          _buildInventoryTabButton('Picked Up', inventoryListings.where((b) => !b.isArchived && b.status == 'Picked Up').length),
                          _buildInventoryTabButton('Archived', inventoryListings.where((b) => b.isArchived).length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (filteredInventory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text('No $_inventoryTab textbooks found.', style: const TextStyle(fontSize: 16, color: Colors.black54)),
                ),
              )
            else
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: filteredInventory.length,
                itemBuilder: (context, index) {
                  final book = filteredInventory[index];
                  return InkWell(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TextbookDetailsPage(textbook: book, showActions: false),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Container(
                            color: Colors.black12,
                            width: double.infinity,
                            child: book.imageUrl != null
                                ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.menu_book, color: Colors.white, size: 50),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM ${book.listingPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A), fontSize: 14),
                            ),
                            if (book.isArchived) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Restore Button
                                  InkWell(
                                    onTap: () => _showRestoreDialog(book),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.restore, size: 20, color: Colors.green),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Hard Delete Button
                                  InkWell(
                                    onTap: () => _showHardDeleteDialog(book),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (book.status == 'Available' || book.status == 'Pending Edit') ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (book.status == 'Pending Edit')
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('PENDING EDIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  Row(
                                    children: [
                                      // Edit Button
                                      InkWell(
                                        onTap: () => setState(() {
                                          _editingTextbook = book;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: const Color(0xFF023E8A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF023E8A)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Archive Button
                                      InkWell(
                                        onTap: () => _showArchiveDialog(book),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: book.status == 'Picked Up' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    book.status.toUpperCase(), 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold, 
                                      color: book.status == 'Picked Up' ? Colors.green : Colors.orange
                                    )
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTabButton(String tabName, int count) {
    final isSelected = _inventoryTab == tabName;
    return InkWell(
      onTap: () => setState(() => _inventoryTab = tabName),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          '$tabName ($count)',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF023E8A) : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersManagementView(bool isDesktop) {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.receipt_long, size: 100, color: Colors.black26),
            SizedBox(height: 24),
            Text('No Orders Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            SizedBox(height: 8),
            Text('When users buy textbooks, they will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          TextField(
            controller: _orderSearchController,
            onChanged: (value) => setState(() { _ordersCurrentPage = 1; }),
            decoration: InputDecoration(
              hintText: 'Search by Order ID',
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date Range', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showDateRangeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDateRange == null 
                                  ? 'All Dates' 
                                  : '${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                            if (_selectedDateRange != null)
                              InkWell(
                                onTap: () => setState(() => _selectedDateRange = null),
                                child: const Icon(Icons.clear, size: 16, color: Colors.black54),
                              )
                            else
                              const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildOrderFilterDropdown(
                'Order Status', 
                ['Action Required', 'Placed', 'Completed', 'Cancel Requested', 'Cancelled', 'All'], 
                _orderStatusFilter, 
                (v) => setState(() { 
                  _orderStatusFilter = v!; 
                  _pickupStatusFilter = 'All';
                  _ordersCurrentPage = 1; 
                  if (v == 'Action Required') {
                    _pickupStatusFilter = 'Pending';
                  } else {
                    _pickupStatusFilter = 'All';
                  }
                })
              ),
              const SizedBox(width: 16),
              _buildOrderFilterDropdown(
                'Pickup Status', 
                ['Pending', 'Picked Up', 'All'], 
                _pickupStatusFilter, 
                (v) => setState(() { _pickupStatusFilter = v!; _ordersCurrentPage = 1; }),
                isEnabled: _orderStatusFilter != 'Cancelled'
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(8),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: DataTable(
                showCheckboxColumn: false,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14),
                dataTextStyle: const TextStyle(color: Colors.black87, fontSize: 14),
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: SizedBox(width: 80, child: Text('Order ID'))),
                  DataColumn(label: SizedBox(width: 80, child: Text('Date'))),
                  DataColumn(label: SizedBox(width: 200, child: Text('Textbook'))),
                  DataColumn(label: SizedBox(width: 80, child: Text('Total'))),
                  DataColumn(label: SizedBox(width: 100, child: Text('Order Status'))),
                  DataColumn(label: SizedBox(width: 100, child: Text('Pickup Status'))),
                  DataColumn(label: SizedBox(width: 100, child: Text('Payment Status'))),
                ],
                rows: _getFilteredOrders()
                    .skip((_ordersCurrentPage - 1) * _ordersPerPage)
                    .take(_ordersPerPage)
                    .map((order) {
                  final items = order.items ?? [];
                  final textbookTitle = items.isEmpty 
                      ? 'Unknown' 
                      : (items.length == 1 
                          ? (items.first.textbook?.title ?? 'Unknown') 
                          : '${items.first.textbook?.title} +${items.length - 1} more');
                  final textbookIds = items.map((i) => i.textbookID).toList();
                  
                  final payments = order.payments ?? [];
                  final payment = payments.isNotEmpty ? payments.first : null;

                  final oStatus = order.status;
                  final rawPStatus = payment?.pickupStatus;
                  final pStatus = (rawPStatus == null || rawPStatus.isEmpty) 
                        ? (oStatus == 'Cancelled' ? '-' : 'Pending') 
                        : rawPStatus;

                  final dateFormatted = order.orderedAt.split('T')[0];

                  return DataRow(
                    onSelectChanged: (_) => _showOrderDetails(order),
                    cells: [
                      DataCell(Text('#${order.orderID.toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(dateFormatted)),
                      DataCell(SizedBox(width: 200, child: Text(textbookTitle, overflow: TextOverflow.ellipsis))),
                      DataCell(Text('RM ${order.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: oStatus == 'Completed' ? Colors.green.withOpacity(0.1) : (oStatus == 'Cancelled' ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(oStatus, style: TextStyle(color: oStatus == 'Completed' ? Colors.green : (oStatus == 'Cancelled' ? Colors.red : Colors.orange), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: pStatus == 'Picked Up' ? Colors.green.withOpacity(0.1) : (pStatus == '-' ? Colors.black12 : Colors.blue.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(pStatus, style: TextStyle(color: pStatus == 'Picked Up' ? Colors.green : (pStatus == '-' ? Colors.black54 : Colors.blue), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: payment?.paymentStatus == 'Refunded' ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(payment?.paymentStatus ?? 'Paid', style: TextStyle(color: payment?.paymentStatus == 'Refunded' ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _ordersCurrentPage > 1 ? () => setState(() => _ordersCurrentPage--) : null,
              ),
              Text(
                'Page $_ordersCurrentPage of ${(_getFilteredOrders().length / _ordersPerPage).ceil() == 0 ? 1 : (_getFilteredOrders().length / _ordersPerPage).ceil()}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _ordersCurrentPage < (_getFilteredOrders().length / _ordersPerPage).ceil() ? () => setState(() => _ordersCurrentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFilterDropdown(String label, List<String> options, String currentValue, void Function(String?) onChanged, {bool isEnabled = true}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: IgnorePointer(
              ignoring: !isEnabled,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentValue,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: isEnabled ? Colors.black54 : Colors.black26),
                  items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 14, color: isEnabled ? Colors.black87 : Colors.black38)))).toList(),
                  onChanged: isEnabled ? onChanged : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<OrderModel> _getFilteredOrders() {
    return _orders.where((order) {
      final payments = order.payments ?? [];
      final rawPStatus = payments.isNotEmpty ? payments.first.pickupStatus : null;
      final pStatus = (rawPStatus == null || rawPStatus.isEmpty) 
            ? (order.status == 'Cancelled' ? '-' : 'Pending') 
            : rawPStatus;

      // Status filter
      if (_orderStatusFilter == 'Action Required') {
         if (order.status == 'Cancelled') return false;
         bool isActionable = (order.status == 'Placed' || order.status == 'Cancel Requested' || pStatus == 'Pending');
         if (!isActionable) return false;
      } else if (_orderStatusFilter != 'All' && order.status != _orderStatusFilter) {
         return false;
      }
      
      if (_pickupStatusFilter != 'All' && pStatus != _pickupStatusFilter) return false;

      // Search filter
      if (_orderSearchController.text.isNotEmpty) {
        final query = _orderSearchController.text.toLowerCase();
        final orderIdMatch = order.orderID.toString().toLowerCase().contains(query);
        if (!orderIdMatch) return false;
      }

      // Date filter
      if (_selectedDateRange != null) {
        final orderDate = DateTime.parse(order.orderedAt);
        // Strip time from orderDate for accurate inclusive range comparison
        final normalizedOrderDate = DateTime(orderDate.year, orderDate.month, orderDate.day);
        final normalizedStart = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final normalizedEnd = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        
        if (normalizedOrderDate.isBefore(normalizedStart) || normalizedOrderDate.isAfter(normalizedEnd)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _showDateRangeDialog() async {
    DateTime? tempStart = _selectedDateRange?.start;
    DateTime? tempEnd = _selectedDateRange?.end;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date'),
                  subtitle: Text(tempStart?.toString().split(' ')[0] ?? 'Not selected', style: TextStyle(color: tempStart == null ? Colors.red : Colors.black87)),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: tempStart ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => tempStart = d);
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End Date'),
                  subtitle: Text(tempEnd?.toString().split(' ')[0] ?? 'Not selected', style: TextStyle(color: tempEnd == null ? Colors.red : Colors.black87)),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: tempEnd ?? tempStart ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => tempEnd = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
              ElevatedButton(
                onPressed: () {
                  if (tempStart != null && tempEnd != null) {
                    if (tempEnd!.isBefore(tempStart!)) {
                      final t = tempStart;
                      tempStart = tempEnd;
                      tempEnd = t;
                    }
                    Navigator.pop(context, DateTimeRange(start: tempStart!, end: tempEnd!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both Start and End dates.')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
                child: const Text('Apply'),
              ),
            ],
          );
        }
      )
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _showOrderDetails(OrderModel order) {
    final payments = order.payments ?? [];
    final payment = payments.isNotEmpty ? payments.first : null;
    final oStatus = order.status;
    final pStatus = oStatus == 'Cancelled' ? '-' : (payment?.pickupStatus ?? 'Pending');
    final textbookIds = order.items?.map((i) => i.textbookID).toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFF8F9FA),
        child: Container(
          width: 700,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order #${order.orderID.toString().substring(0, 8).toUpperCase()}', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF023E8A))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildDetailColumn('Date Placed', order.orderedAt.split("T")[0], Icons.calendar_today),
                  _buildDetailColumn('Total Price', 'RM ${order.totalPrice.toStringAsFixed(2)}', Icons.payments_outlined),
                  _buildDetailColumn('Order Status', oStatus, Icons.receipt_long_outlined),
                  _buildDetailColumn('Pickup Status', pStatus, Icons.handshake_outlined),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Purchased Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items?.length ?? 0,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final item = order.items![index];
                    return InkWell(
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      onTap: () {
                        if (item.textbook != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TextbookDetailsPage(
                                textbook: item.textbook!,
                                showActions: false,
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            if (item.textbook?.imageUrl != null && item.textbook!.imageUrl!.isNotEmpty)
                              Container(
                                width: 64,
                                height: 64,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(item.textbook!.imageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 64,
                                height: 64,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.book, color: Colors.black38, size: 32),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.textbook?.title ?? 'Unknown Book',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Tap to view details', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                ],
                              ),
                            ),
                            Text(
                              'RM ${item.priceAtPurchase.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (order.cancelReason != null && order.cancelReason!.isNotEmpty) ...() {
                final parts = order.cancelReason!.split('\n--- Bank Details ---\n');
                final reasonText = parts[0];
                final bankText = parts.length > 1 ? parts[1] : '';
                return [
                  const Text('Cancellation Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [Icon(Icons.feedback_outlined, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Reason for Cancellation', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))]),
                                const SizedBox(height: 8),
                                Text(reasonText, style: const TextStyle(color: Colors.black87)),
                              ],
                            ),
                          ),
                        ),
                        if (bankText.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [Icon(Icons.account_balance_outlined, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Bank Details for Refund', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                                  const SizedBox(height: 8),
                                  Text(bankText, style: const TextStyle(color: Colors.black87, height: 1.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ];
              }(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (oStatus == 'Cancel Requested') ...[
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close order details dialog first
                        _showRejectCancelDialog(order);
                      },
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black54), foregroundColor: Colors.black87),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) {
                            Uint8List? receiptBytes;
                            String? receiptExt;
                            bool isUploading = false;
                            
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Have you manually transferred the refund to the user\'s bank account?'),
                                      const SizedBox(height: 16),
                                      const Text('Please upload the transfer receipt below to proceed:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      if (receiptBytes != null)
                                        Container(
                                          height: 150,
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.black12),
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(image: MemoryImage(receiptBytes!), fit: BoxFit.cover),
                                          ),
                                        ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: isUploading ? null : () async {
                                            final ImagePicker picker = ImagePicker();
                                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                            if (image != null) {
                                              final bytes = await image.readAsBytes();
                                              final ext = image.name.split('.').last;
                                              setState(() {
                                                receiptBytes = bytes;
                                                receiptExt = ext;
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.upload_file),
                                          label: Text(receiptBytes == null ? 'Upload Receipt' : 'Change Receipt'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    if (!isUploading)
                                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
                                    ElevatedButton(
                                      onPressed: (receiptBytes == null || isUploading) ? null : () async {
                                        setState(() => isUploading = true);
                                        try {
                                          final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.$receiptExt';
                                          final url = await _orderService.uploadRefundReceipt(fileName, receiptBytes!, receiptExt!);
                                          
                                          await _orderService.approveOrderCancel(order.orderID, payment?.paymentID, textbookIds, receiptUrl: url, buyerId: order.buyerID);
                                          
                                          if (mounted) {
                                            Navigator.pop(dialogContext); // close confirm dialog
                                            Navigator.pop(this.context); // close order details dialog
                                            _fetchOrders();
                                            _fetchInventory();
                                            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Cancellation approved and receipt uploaded')));
                                          }
                                        } catch (e) {
                                          setState(() => isUploading = false);
                                          if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      child: isUploading 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('Yes, Approve & Refund'),
                                    ),
                                  ],
                                );
                              }
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Approve & Refund'),
                    ),
                  ],
                  if (pStatus != 'Picked Up' && payment != null && oStatus != 'Completed' && oStatus != 'Cancel Requested' && oStatus != 'Cancelled')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPinVerificationDialog(order, payment.paymentID, textbookIds);
                      },
                      icon: const Icon(Icons.handshake_outlined, size: 18),
                      label: const Text('Pick Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF023E8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          ),
        ),
      )
    );
  }

  Widget _buildDetailColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildProfileView(bool isDesktop) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Avatar & Info)
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF023E8A),
                    child: Text(_initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userEmail, style: const TextStyle(fontSize: 18, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF023E8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(color: Color(0xFF023E8A), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 40),
              
              // Form Section
              const Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 24),
              
              _buildTextField('Full Name', _nameController),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              
              const Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Change Password'),
                        content: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter new password',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              _passwordController.clear();
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleUpdateProfile(); // Trigger save
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
                            child: const Text('Update Password'),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.lock_outline, size: 18, color: Colors.black54),
                label: const Text('Change Password', style: TextStyle(color: Colors.black54)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF023E8A), // Dark blue
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF023E8A))),
          ),
        ),
      ],
    );
  }
}
