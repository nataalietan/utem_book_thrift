import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import 'textbook_details_page.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool _isLoading = true;
  List<OrderModel> _orders = [];

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

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final _authService = AuthService();
      final _orderService = OrderService();
      
      final user = _authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      final data = await _orderService.fetchUserOrders(user.id);

      setState(() {
        _orders = data;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching orders: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCancelDialog(OrderModel order) {
    final reasonController = TextEditingController();
    final bankNameController = TextEditingController();
    final holderNameController = TextEditingController();
    final accountNoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Order Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please provide a reason for cancellation:'),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Reason for cancelling'),
                ),
                const SizedBox(height: 24),
                const Text('Bank Account Details (For Refund)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Bank Name (e.g. Maybank)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderNameController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Account Holder Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Account Number'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty || bankNameController.text.trim().isEmpty || holderNameController.text.trim().isEmpty || accountNoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
                return;
              }
              final fullReason = '${reasonController.text.trim()}\n--- Bank Details ---\nBank Name: ${bankNameController.text.trim()}\nHolder Name: ${holderNameController.text.trim()}\nAccount No: ${accountNoController.text.trim()}';
              
              try {
                final _orderService = OrderService();
                await _orderService.requestOrderCancel(order.orderID, fullReason);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation request sent')));
                  _fetchOrders();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'placed': return Colors.blue;
      case 'cancel requested': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 800 ? 60.0 : 20.0, vertical: 10.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text('Order Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.receipt_long, size: 80, color: Colors.black26),
                  SizedBox(height: 16),
                  Text('No Orders Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 8),
                  Text('When you buy a textbook, you can track it here.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final payments = order.payments ?? [];
                final payment = payments.isNotEmpty ? payments.first : null;
                
                final statusColor = _getStatusColor(order.status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                                  Text(
                                    'Order #${order.orderID}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Placed on: ${order.orderedAt != null ? order.orderedAt!.split("T")[0] : "Unknown date"}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        if (order.items != null && order.items!.isNotEmpty)
                          ...order.items!.map((item) {
                            final textbook = item.textbook;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: textbook != null ? () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => TextbookDetailsPage(textbook: textbook, showActions: order.status == 'Cancelled')));
                                } : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(8),
                                        image: textbook?.imageUrl != null 
                                          ? DecorationImage(image: NetworkImage(textbook!.imageUrl!), fit: BoxFit.cover) 
                                          : null,
                                      ),
                                      child: textbook?.imageUrl == null 
                                          ? const Icon(Icons.menu_book, color: Colors.white, size: 40) 
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(textbook?.title ?? 'Unknown Textbook', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          const SizedBox(height: 8),
                                          Text('Condition: ${_getConditionText(textbook?.conditionScore)}', style: const TextStyle(color: Colors.black54)),
                                          Text('Seller: ${textbook?.seller?.fullName ?? 'Unknown'}', style: const TextStyle(color: Colors.black54)),
                                          const SizedBox(height: 4),
                                          Text('RM ${item.priceAtPurchase.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A), fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Order Total: RM ${order.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (order.pickupPin != null && order.status != 'Cancelled')
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF023E8A).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF023E8A).withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lock_outline, color: Color(0xFF023E8A), size: 20),
                                    SizedBox(width: 8),
                                    Text('Pickup PIN:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A))),
                                  ],
                                ),
                                Text(
                                  order.pickupPin!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 4, color: Color(0xFF023E8A)),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Payment Method', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(payment?.paymentMethod ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                              if (payment?.paymentStatus == 'Refunded')
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('Payment Status', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                    SizedBox(height: 4),
                                    Text('Refunded', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Pickup Status', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.status == 'Cancelled' ? '-' : (payment?.pickupStatus ?? 'Pending'), 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: order.status == 'Cancelled' ? Colors.black54 : (payment?.pickupStatus == 'Picked Up' ? Colors.green : Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (payment?.refundReceiptUrl != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Stack(
                                      children: [
                                        InteractiveViewer(
                                          child: Image.network(payment!.refundReceiptUrl!),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.black54),
                                            onPressed: () => Navigator.pop(context),
                                            style: IconButton.styleFrom(backgroundColor: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('View Refund Receipt'),
                            ),
                          ),
                        ],
                        if (order.status == 'Placed') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showCancelDialog(order),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Request Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
