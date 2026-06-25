import 'package:flutter/material.dart';
import '../models/textbook_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';

class CheckoutPage extends StatefulWidget {
  final List<TextbookModel> selectedBooks;
  final double totalPrice;

  const CheckoutPage({
    super.key,
    required this.selectedBooks,
    required this.totalPrice,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();
  final NotificationService _notificationService = NotificationService();

  UserModel? _buyer;
  String _selectedPaymentMethod = 'Online Banking';
  bool _isLoading = true;
  String? _errorMessage;

  String _getConditionText(int? score) {
    switch (score) {
      case 5: return 'Brand New';
      case 4: return 'Like New';
      case 3: return 'Good';
      case 2: return 'Acceptable';
      case 1: return 'Worn';
      default: return 'Unknown';
    }
  }

  bool _isPlacingOrder = false;

  final List<String> _paymentMethods = [
    'Online Banking',
    'E-Wallet',
    'Credit/Debit Card'
  ];

  @override
  void initState() {
    super.initState();
    _fetchBuyerDetails();
  }

  Future<void> _fetchBuyerDetails() async {
    final user = _authService.currentUser;
    if (user != null) {
      final buyerDetails = await _userService.fetchUser(user.id);
      if (mounted) {
        setState(() {
          _buyer = buyerDetails;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _placeOrder() async {
    final user = _authService.currentUser;
    if (user == null || _buyer == null) return;

    setState(() => _isPlacingOrder = true);

    try {
      await _orderService.placeOrder(
        buyerID: user.id,
        textbooks: widget.selectedBooks,
        totalPrice: widget.totalPrice,
        paymentMethod: _selectedPaymentMethod,
      );



      _notificationService.sendAdminNotification(
        title: 'New Order Placed',
        message: 'A new order for ${widget.selectedBooks.length} book(s) has been placed by ${_buyer?.fullName ?? 'a user'}.',
        type: 'order_placed',
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Order Placed Successfully!')),
          ],
        ),
        content: const Text(
          'Your payment has been processed and your textbooks are reserved. You can view your order status in the Order Tracking page.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Pop the dialog
              Navigator.pop(context);
              // Pop the checkout page
              Navigator.pop(context, true); // Return true to indicate success
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
            child: const Text('Back to Browse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0, vertical: 10.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text('Checkout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 60.0 : 20.0,
          vertical: 40.0,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Information
                _buildSectionContainer(
                  title: 'Contact Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, color: Colors.black54),
                          const SizedBox(width: 16),
                          Text(_buyer?.fullName ?? 'Unknown User', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.black54),
                          const SizedBox(width: 16),
                          Text(_authService.currentUser?.email ?? 'No email', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Order Summary
                _buildSectionContainer(
                  title: 'Order Summary (${widget.selectedBooks.length} items)',
                  child: Column(
                    children: widget.selectedBooks.map((book) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: book.imageUrl != null
                                ? Image.network(book.imageUrl!, width: 60, height: 80, fit: BoxFit.cover)
                                : Container(width: 60, height: 80, color: Colors.black12, child: const Icon(Icons.menu_book, color: Colors.white)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Condition: ${_getConditionText(book.conditionScore)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                Text('Seller: ${book.seller?.fullName ?? 'Unknown'}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('RM ${book.listingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF023E8A))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Pickup Method
                _buildSectionContainer(
                  title: 'Pickup Method',
                  child: DropdownButtonFormField<String>(
                    value: 'Pickup at Bookstore',
                    items: const [
                      DropdownMenuItem(
                        value: 'Pickup at Bookstore',
                        child: Text('Pickup at Bookstore'),
                      )
                    ],
                    onChanged: null, // Disabled dropdown
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method
                _buildSectionContainer(
                  title: 'Payment Method',
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    items: _paymentMethods.map((method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMethod = val);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Total and Place Order
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('RM ${widget.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isPlacingOrder ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: const Color(0xFF023E8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          disabledBackgroundColor: Colors.grey[400],
                        ),
                        child: _isPlacingOrder
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Place Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
