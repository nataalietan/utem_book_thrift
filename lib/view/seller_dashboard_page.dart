import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/textbook_service.dart';
import '../models/textbook_model.dart';
import 'add_listing_page.dart';
import 'edit_listing_page.dart';
import 'textbook_details_page.dart';
import '../services/notification_service.dart';

class SellerDashboardPage extends StatefulWidget {
  final String? initialTab;
  const SellerDashboardPage({super.key, this.initialTab});

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  final _textbookService = TextbookService();
  final _authService = AuthService();
  final _notificationService = NotificationService();

  List<TextbookModel> _myListings = [];
  bool _isLoading = true;
  String _currentTab = 'Available';

  bool _isAddingListing = false;
  TextbookModel? _editingTextbook;
  final GlobalKey<EditListingPageState> _editKey = GlobalKey();

  final List<String> _tabs = ['Available', 'Pending Drop-off', 'Pending Approval', 'Rejected', 'Removed', 'My Income'];

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _currentTab = widget.initialTab!;
    }
    _fetchMyListings();
  }

  Future<void> _fetchMyListings() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final data = await _textbookService.fetchSellerBooks(user.id);
        setState(() {
          _myListings = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching seller books: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteListing(TextbookModel book) async {
    if (book.status == 'Pending Drop-off') {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request Deletion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This book is pending drop-off. Please provide a reason for cancelling this listing.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      );

      if (confirm == true && reasonController.text.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          await _textbookService.updateTextbook(book.textbookID, {
            'isDeleteRequested': true,
            'deleteRequestReason': reasonController.text.trim(),
          });
          _notificationService.sendAdminNotification(
            title: 'Delete Request',
            message: 'A seller has requested to cancel the pending drop-off for "${book.title}".',
            type: 'delete_request',
          );
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request submitted.')));
          await _fetchMyListings();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Listing'),
          content: const Text('Are you sure you want to delete this textbook listing?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        try {
          if (book.imageUrl != null) {
            await _textbookService.deleteImage(book.imageUrl!);
          }
          await _textbookService.deleteTextbook(book.textbookID);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted successfully')));
          await _fetchMyListings();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting listing: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _getTabDescription() {
    switch (_currentTab) {
      case 'Available':
        return 'Your textbooks that are currently available for sale on the platform.';
      case 'Pending Drop-off':
        return 'Textbooks to be dropped off at the bookstore after listing is approved.';
      case 'Pending Approval':
        return 'Listings submitted and waiting for admin approval.';
      case 'Rejected':
        return 'Listings that were rejected by admin.';
      case 'Removed':
        return 'Listings deleted by admin.';
      case 'My Income':
        return 'Textbooks you have successfully handed over to the bookstore.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    String pageTitle = 'My Listings';
    if (_isAddingListing) {
      pageTitle = 'List a Textbook';
    } else if (_editingTextbook != null) {
      pageTitle = 'Edit Textbook';
    }

    return Scaffold(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () {
                        if (_isAddingListing) {
                          setState(() => _isAddingListing = false);
                        } else if (_editingTextbook != null) {
                          if (_editKey.currentState != null) {
                            _editKey.currentState!.handleBack();
                          } else {
                            setState(() => _editingTextbook = null);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(pageTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: _buildBody(),
      floatingActionButton: (!_isAddingListing && _editingTextbook == null)
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() => _isAddingListing = true);
              },
              backgroundColor: const Color(0xFF023E8A),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Sell a Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isAddingListing) {
      return AddListingPage(
        onBack: () {
          setState(() => _isAddingListing = false);
          _fetchMyListings();
        },
        onSubmitted: () {
          setState(() => _currentTab = 'Pending Approval');
        },
      );
    }

    if (_editingTextbook != null) {
      return EditListingPage(
        key: _editKey,
        textbook: _editingTextbook!,
        onBack: () {
          setState(() => _editingTextbook = null);
          _fetchMyListings();
        },
        onSubmitted: () {
          setState(() => _currentTab = 'Pending Approval');
        },
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredListings = _myListings.where((b) {
      if (_currentTab == 'Available') return b.status == 'Available';
      if (_currentTab == 'Pending Drop-off') return b.status == 'Pending Drop-off';
      if (_currentTab == 'Pending Approval') return b.status == 'Pending Approval';
      if (_currentTab == 'Rejected') return b.status == 'Rejected';
      if (_currentTab == 'Removed') return b.status == 'Deleted by Admin';
      if (_currentTab == 'My Income') return b.status == 'Available' || b.status == 'Sold' || b.status == 'Picked Up' || b.status == 'Pending Edit' || b.isArchived;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row (Description + Tabs)
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 16.0),
          child: MediaQuery.of(context).size.width > 800
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _getTabDescription(),
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: _tabs.map((tab) {
                            final isSelected = _currentTab == tab;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(tab),
                                selected: isSelected,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) setState(() => _currentTab = tab);
                                },
                                selectedColor: const Color(0xFF023E8A),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF023E8A) : Colors.black12,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tabs.map((tab) {
                          final isSelected = _currentTab == tab;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(tab),
                              selected: isSelected,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) setState(() => _currentTab = tab);
                              },
                              selectedColor: const Color(0xFF023E8A),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF023E8A) : Colors.black12,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getTabDescription(),
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
        ),

        // Grid View
        Expanded(
          child: filteredListings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.black26),
                      const SizedBox(height: 16),
                      Text('No $_currentTab listings found.', style: const TextStyle(fontSize: 16, color: Colors.black54)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _currentTab == 'My Income'
                      ? ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredListings.length,
                          itemBuilder: (context, index) {
                            final book = filteredListings[index];
                            return _buildIncomeListTile(book);
                          },
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredListings.length,
                        itemBuilder: (context, index) {
                          final book = filteredListings[index];
                          return _buildTextbookCard(book);
                        },
                      );
                    }
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTextbookCard(TextbookModel book) {
    final bool canEdit = book.status == 'Pending Approval' || book.status == 'Rejected';
    final bool canDelete = book.status == 'Pending Approval' || book.status == 'Rejected' || book.status == 'Pending Drop-off' || book.status == 'Deleted by Admin';
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextbookDetailsPage(textbook: book, showActions: false, isSellerView: true),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: book.status == 'Rejected' ? Border.all(color: Colors.red.withOpacity(0.5), width: 2) : Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  color: Colors.black12,
                  width: double.infinity,
                  child: book.imageUrl != null
                      ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.menu_book, color: Colors.white, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (_currentTab == 'My Income')
                    Text(
                      'Income Earned: RM ${book.sellerEarnings?.toStringAsFixed(2) ?? book.listingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                    )
                  else
                    Text(
                      'RM ${book.listingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A), fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  
                  if (_currentTab != 'My Income') ...[
                    if ((book.status == 'Rejected' || book.status == 'Deleted by Admin') && book.rejectionReason != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(child: Text(book.rejectionReason!, style: const TextStyle(fontSize: 11, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),

                  if (book.status == 'Pending Drop-off' && book.dropOffPin != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF023E8A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pin_outlined, size: 14, color: Color(0xFF023E8A)),
                          const SizedBox(width: 4),
                          Text(
                            'Drop-off PIN: ${book.dropOffPin}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF023E8A), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (book.isDeleteRequested)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: const Text('Delete Requested', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else if (canEdit || canDelete) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canEdit)
                          InkWell(
                            onTap: () {
                              setState(() => _editingTextbook = book);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            ),
                          )
                        else
                          const SizedBox(), // Spacer if no edit button
                        if (canDelete)
                          InkWell(
                            onTap: () => _deleteListing(book),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    if (book.status == 'Sold' || book.status == 'Picked Up')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        alignment: Alignment.center,
                        child: Text(book.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: book.status == 'Available' ? Colors.green.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(book.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: book.status == 'Available' ? Colors.green : Colors.black54)),
                      ),
                  ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeListTile(TextbookModel book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (book.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(book.imageUrl!, width: 48, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 48, height: 60, color: Colors.grey[200], child: const Icon(Icons.menu_book, color: Colors.black26))),
            )
          else
            Container(
              width: 48,
              height: 60,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.menu_book, color: Colors.black26),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '+ RM ${book.sellerEarnings?.toStringAsFixed(2) ?? book.listingPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
