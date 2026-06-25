import 'package:flutter/material.dart';
import '../models/textbook_model.dart';
import '../services/wishlist_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import 'login_signup_page.dart';

class TextbookDetailsPage extends StatefulWidget {
  final TextbookModel textbook;
  final bool showActions;
  final bool isSellerView;

  const TextbookDetailsPage({super.key, required this.textbook, this.showActions = true, this.isSellerView = false});

  @override
  State<TextbookDetailsPage> createState() => _TextbookDetailsPageState();
}

class _TextbookDetailsPageState extends State<TextbookDetailsPage> {
  final _wishlistService = WishlistService();
  final _cartService = CartService();
  final _authService = AuthService();

  bool _isInWishlist = false;
  bool _isInCart = false;

  void _showFullImageDialog() {
    if (widget.textbook.imageUrl == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(widget.textbook.imageUrl!, fit: BoxFit.contain),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_authService.currentUser != null) {
      final wishlistStatus = await _wishlistService.isInWishlist(widget.textbook.textbookID);
      final cartStatus = await _cartService.isInCart(widget.textbook.textbookID);
      if (mounted) {
        setState(() {
          _isInWishlist = wishlistStatus;
          _isInCart = cartStatus;
        });
      }
    }
  }

  void _requireAuth(VoidCallback onAuthenticated) {
    if (_authService.currentUser != null) {
      onAuthenticated();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('You need to be logged in to perform this action.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginSignupPage()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF023E8A), foregroundColor: Colors.white),
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleWishlist() async {
    bool isAdding = !_isInWishlist;
    setState(() => _isInWishlist = isAdding);
    try {
      await _wishlistService.toggleWishlist(widget.textbook.textbookID);
    } catch (e) {
      setState(() => _isInWishlist = !isAdding);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update wishlist')));
    }
  }

  Future<void> _toggleCart() async {
    bool isAdding = !_isInCart;
    setState(() => _isInCart = isAdding);
    try {
      await _cartService.toggleCart(widget.textbook.textbookID);
    } catch (e) {
      setState(() => _isInCart = !isAdding);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update bag')));
    }
  }

  String _getConditionText(int? score) {
    switch (score) {
      case 5: return 'Brand New';
      case 4: return 'Like New';
      case 3: return 'Good';
      case 2: return 'Acceptable';
      default: return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

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
                const Text('Textbook Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.textbook.status == 'Pending Drop-off' && widget.textbook.dropOffPin != null && widget.isSellerView)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF023E8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pin_outlined, size: 24, color: Color(0xFF023E8A)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Drop-off PIN: ${widget.textbook.dropOffPin}',
                                style: const TextStyle(fontSize: 16, color: Color(0xFF023E8A), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (widget.isSellerView) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Note: Please provide this PIN to the admin when dropping off your textbook for verification.\nYou will receive the money for your textbook once you drop it off at the bookstore.',
                            style: TextStyle(fontSize: 13, color: const Color(0xFF023E8A).withOpacity(0.8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                if ((widget.textbook.status == 'Rejected' || widget.textbook.status == 'Deleted by Admin') && widget.textbook.rejectionReason != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 24, color: Colors.red),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.textbook.status == 'Deleted by Admin' 
                                    ? 'Deletion Reason: ${widget.textbook.rejectionReason}'
                                    : 'Rejection Reason: ${widget.textbook.rejectionReason}',
                                style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.textbook.status == 'Deleted by Admin'
                              ? 'Note: This listing has been removed from the platform by an admin.'
                              : 'Note: You can edit your listing to resolve these issues. Once saved, it will be automatically resubmitted for approval.',
                          style: TextStyle(fontSize: 13, color: Colors.red.withOpacity(0.8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showFullImageDialog,
                        child: Container(
                          height: 400,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                            image: widget.textbook.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(widget.textbook.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: widget.textbook.imageUrl == null
                              ? const Center(child: Icon(Icons.menu_book, size: 100, color: Colors.black12))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          const Text(
                            'Tap the image to view it in full screen',
                            style: TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isDesktop ? 40 : 0, height: isDesktop ? 0 : 32),
                
                // Details
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.textbook.title,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final isOwnBook = _authService.currentUser?.id == widget.textbook.sellerID;
                              if (widget.showActions && !isOwnBook) {
                                return Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _isInCart ? Colors.green : const Color(0xFF023E8A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          _isInCart ? Icons.shopping_bag : Icons.shopping_bag_outlined, 
                                          color: Colors.white, size: 20
                                        ),
                                        onPressed: () => _requireAuth(_toggleCart),
                                        tooltip: _isInCart ? 'Remove from Bag' : 'Add to Bag',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        _isInWishlist ? Icons.favorite : Icons.favorite_border,
                                        color: _isInWishlist ? Colors.red : Colors.black87,
                                        size: 24
                                      ),
                                      onPressed: () => _requireAuth(_toggleWishlist),
                                      tooltip: _isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                                    ),
                                  ],
                                );
                              } else if (widget.showActions && isOwnBook) {
                                return const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text('Your Listing', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'RM ${widget.textbook.listingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          if (widget.textbook.originalPrice > widget.textbook.listingPrice)
                            Text(
                              'RM ${widget.textbook.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, color: Colors.black45, decoration: TextDecoration.lineThrough),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      _buildInfoRow('Faculty', widget.textbook.faculty?.isNotEmpty == true ? widget.textbook.faculty! : '-'),
                      _buildInfoRow('Domain', widget.textbook.domain.isNotEmpty ? widget.textbook.domain : '-'),
                      _buildInfoRow('Study Level', widget.textbook.studyLevel?.isNotEmpty == true ? widget.textbook.studyLevel! : '-'),
                      _buildInfoRow('Edition', widget.textbook.edition != null ? '${widget.textbook.edition} (${widget.textbook.isLatestEdition ? "Latest Edition" : "Not Latest Edition"})' : '-'),
                      _buildInfoRow('Condition', _getConditionText(widget.textbook.conditionScore)),
                      _buildInfoRow('Status', widget.textbook.status.isNotEmpty ? widget.textbook.status : '-'),
                      _buildInfoRow('Seller', widget.textbook.seller?.fullName ?? 'Unknown'),
                      
                      const SizedBox(height: 24),
                      const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        widget.textbook.description?.isNotEmpty == true ? widget.textbook.description! : '-',
                        style: const TextStyle(color: Colors.black54, height: 1.5),
                      ),
                      
                      const SizedBox(height: 32),
                      if (widget.textbook.seller != null) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: const Icon(Icons.person, color: Colors.black54),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Listed by', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                Text(widget.textbook.seller!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
