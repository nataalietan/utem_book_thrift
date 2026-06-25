import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/textbook_service.dart';
import '../models/textbook_model.dart';
import 'login_signup_page.dart';
import 'profile_page.dart';
import 'order_tracking_page.dart';
import 'textbook_details_page.dart';
import 'checkout_page.dart';
import '../services/wishlist_service.dart';
import '../services/cart_service.dart';
import 'seller_dashboard_page.dart';
import 'widgets/notification_badge.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeSidePanel = 'wishlist';
  bool _isFiltersExpanded = false;

  final TextEditingController _searchController = TextEditingController();

  String selectedFaculty = 'All';
  String selectedDomain = 'All';
  String selectedStudyLevel = 'All';

  final List<String> faculties = ['All', 'FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'SPAB', 'IPTK'];
  final List<String> domains = ['All', 'Computer Science & IT', 'Engineering & Engineering Technology', 'Business & Technology Management', 'Mathematics & Sciences', 'Humanities & Social Sciences', 'Languages & Linguistics', 'Research Methodology'];
  final List<String> studyLevels = ['All', 'Diploma', 'Degree', 'Master\'s', 'PhD'];

  List<TextbookModel> books = [];
  bool _isLoading = true;

  Set<dynamic> _wishlistIds = {};
  Set<dynamic> _cartIds = {};
  Set<dynamic> _selectedCartIds = {};
  List<TextbookModel> _wishlistBooks = [];
  List<TextbookModel> _cartBooks = [];
  bool _isWishlistLoading = false;
  bool _isCartLoading = false;

  final _wishlistService = WishlistService();
  final _cartService = CartService();

  List<TextbookModel> get filteredBooks {
    bool isDefaultState = _searchController.text.isEmpty && selectedFaculty == 'All' && selectedDomain == 'All' && selectedStudyLevel == 'All';
    List<String> recommendedDomains = [];

    if (isDefaultState) {
      final user = AuthService().currentUser;
      if (user != null) {
        final faculty = user.userMetadata?['faculty'];
        if (faculty != null) {
          recommendedDomains = _getRecommendedDomains(faculty);
        }
      }
    }

    return books.where((book) {
      final matchesSearch = _searchController.text.isEmpty || book.title.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesFaculty = selectedFaculty == 'All' || book.faculty == selectedFaculty;
      final matchesDomain = selectedDomain == 'All' || book.domain == selectedDomain;
      final matchesStudyLevel = selectedStudyLevel == 'All' || (book.studyLevel != null && book.studyLevel == selectedStudyLevel);
      
      bool matchesDefaultRecommendation = true;
      if (isDefaultState && recommendedDomains.isNotEmpty) {
        matchesDefaultRecommendation = recommendedDomains.contains(book.domain);
      }

      return matchesSearch && matchesFaculty && matchesDomain && matchesStudyLevel && matchesDefaultRecommendation;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchBooks();
    _fetchUserLists();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _fetchUserLists() async {
    final _authService = AuthService();
    if (_authService.currentUser != null) {
      setState(() {
        _isWishlistLoading = true;
        _isCartLoading = true;
      });
      
      final wishlist = await _wishlistService.getWishlist();
      final cart = await _cartService.getCart();
      
      if (mounted) {
        setState(() {
          _wishlistBooks = wishlist;
          _wishlistIds = wishlist.map((b) => b.textbookID).toSet();
          _isWishlistLoading = false;

          _cartBooks = cart;
          _cartIds = cart.map((b) => b.textbookID).toSet();
          _isCartLoading = false;
        });
      }
    }
  }

  Future<void> _fetchBooks() async {
    setState(() => _isLoading = true);
    final _textbookService = TextbookService();
    try {
      final data = await _textbookService.fetchAvailableBooks();
      setState(() {
        books = data;
      });
    } catch (e) {
      debugPrint('Error fetching books: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _requireAuth(VoidCallback onAuthenticated) {
    final _authService = AuthService();
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

  void _openSidePanel(String panel) {
    setState(() {
      _activeSidePanel = panel;
    });
    _fetchUserLists(); // Refresh data before opening
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _toggleWishlist(TextbookModel book) async {
    bool isAdding = !_wishlistIds.contains(book.textbookID);
    
    // Optimistic UI update
    setState(() {
      if (isAdding) {
        _wishlistIds.add(book.textbookID);
      } else {
        _wishlistIds.remove(book.textbookID);
      }
    });

    try {
      await _wishlistService.toggleWishlist(book.textbookID);
      _fetchUserLists(); // Sync with server
    } catch (e) {
      // Revert if failed
      setState(() {
        if (isAdding) {
          _wishlistIds.remove(book.textbookID);
        } else {
          _wishlistIds.add(book.textbookID);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update wishlist')));
    }
  }

  Future<void> _toggleCart(TextbookModel book) async {
    bool isAdding = !_cartIds.contains(book.textbookID);
    
    setState(() {
      if (isAdding) {
        _cartIds.add(book.textbookID);
        _selectedCartIds.add(book.textbookID); // Select by default when added
      } else {
        _cartIds.remove(book.textbookID);
        _selectedCartIds.remove(book.textbookID); // Deselect when removed
      }
    });

    try {
      await _cartService.toggleCart(book.textbookID);
      _fetchUserLists(); // Sync with server
    } catch (e) {
      setState(() {
        if (isAdding) {
          _cartIds.remove(book.textbookID);
        } else {
          _cartIds.add(book.textbookID);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update bag')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildSidePanel(),
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0), // Match welcome_page
        child: _buildTopNavBar(context, isDesktop),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60.0 : 24.0, // Match welcome_page padding
            vertical: 40.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Browse Items', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 32),
              
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildSideFiltersBox(),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_searchController.text.isEmpty && selectedFaculty == 'All' && selectedDomain == 'All' && selectedStudyLevel == 'All')
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text('Recommended for you', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ),
                          Text('Showing ${filteredBooks.length} items', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 24),
                          _buildGrid(isDesktop),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                // Top Filters Box for Mobile
                _buildTopFiltersBox(),
                const SizedBox(height: 32),
                if (_searchController.text.isEmpty && selectedFaculty == 'All' && selectedDomain == 'All' && selectedStudyLevel == 'All')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Recommended for you', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                Text('Showing ${filteredBooks.length} items', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 24),
                _buildGrid(isDesktop),
              ],
            ],
          ),
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
            // Logo & Brand (Same spot as welcome_page)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: isDesktop ? 60 : 40, errorBuilder: (c, e, s) => const Icon(Icons.menu_book, color: Color(0xFF0038FF))),
                  ],
                ),
              ),
            ),
            
            // Search Bar in the middle
            if (isDesktop)
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for items...',
                        hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black45),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF023E8A))),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),

            // Top Right Actions
            // Top Right Actions
            Row(
              children: [
                if (isDesktop) ...[
                  ElevatedButton.icon(
                    onPressed: () => _requireAuth(() {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerDashboardPage()));
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF023E8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Sell Textbooks'),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.black87),
                    onPressed: () => _requireAuth(() {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long, color: Colors.black87),
                    onPressed: () => _requireAuth(() {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderTrackingPage()));
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.black87),
                    onPressed: () => _requireAuth(() => _openSidePanel('wishlist')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
                    onPressed: () => _requireAuth(() => _openSidePanel('bag')),
                  ),
                  AuthService().currentUser != null
                      ? const NotificationBadge()
                      : IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                          onPressed: () => _requireAuth(() {}),
                        ),
                ] else ...[
                  AuthService().currentUser != null
                      ? const NotificationBadge()
                      : IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                          onPressed: () => _requireAuth(() {}),
                        ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu, color: Colors.black87),
                    onSelected: (value) {
                      if (value == 'wishlist') {
                        _requireAuth(() => _openSidePanel('wishlist'));
                      } else if (value == 'bag') {
                        _requireAuth(() => _openSidePanel('bag'));
                      } else if (value == 'profile') {
                        _requireAuth(() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())));
                      } else if (value == 'orders') {
                        _requireAuth(() => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderTrackingPage())));
                      } else if (value == 'sell') {
                        _requireAuth(() => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerDashboardPage())));
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Profile'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'orders',
                        child: ListTile(
                          leading: Icon(Icons.receipt_long),
                          title: Text('Orders'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'wishlist',
                        child: ListTile(
                          leading: Icon(Icons.favorite_border),
                          title: Text('Wishlist'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'bag',
                        child: ListTile(
                          leading: Icon(Icons.shopping_bag_outlined),
                          title: Text('Bag'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'sell',
                        child: ListTile(
                          leading: Icon(Icons.storefront_outlined),
                          title: Text('Sell Textbooks'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideFiltersBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 20, color: Colors.black87),
              SizedBox(width: 8),
              Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSearchableDropdownRow('Domain', domains, selectedDomain, (v) => setState(() => selectedDomain = v)),
          const SizedBox(height: 24),
          _buildFilterRow('Faculty', faculties, selectedFaculty, (v) => setState(() => selectedFaculty = v)),
          const SizedBox(height: 24),
          _buildFilterRow('Study Level', studyLevels, selectedStudyLevel, (v) => setState(() => selectedStudyLevel = v)),
        ],
      ),
    );
  }

  Widget _buildTopFiltersBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFiltersExpanded = !_isFiltersExpanded;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 20, color: Colors.black87),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_isFiltersExpanded ? 'Hide Filters' : 'Show Filters', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                  Icon(_isFiltersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black54),
                ],
              ),
            ),
          ),
          if (_isFiltersExpanded) ...[
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchableDropdownRow('Domain', domains, selectedDomain, (v) => setState(() => selectedDomain = v)),
                const SizedBox(height: 24),
                _buildFilterRow('Faculty', faculties, selectedFaculty, (v) => setState(() => selectedFaculty = v)),
                const SizedBox(height: 24),
                _buildFilterRow('Study Level', studyLevels, selectedStudyLevel, (v) => setState(() => selectedStudyLevel = v)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow(String title, List<String> options, String selectedValue, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            bool isSelected = option == selectedValue;
            return InkWell(
              onTap: () => onSelect(option),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF023E8A) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownRow(String title, List<String> options, String selectedValue, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              initialSelection: selectedValue,
              enableFilter: true, // Enables searching
              enableSearch: true,
              width: constraints.maxWidth,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              dropdownMenuEntries: options.map<DropdownMenuEntry<String>>((String value) {
                return DropdownMenuEntry<String>(value: value, label: value);
              }).toList(),
              onSelected: (String? value) {
                if (value != null) onSelect(value);
              },
            );
          },
        ),
      ],
    );
  }



  Widget _buildGrid(bool isDesktop) {
    final filtered = filteredBooks;
    
    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No textbooks found matching your filters.', style: TextStyle(fontSize: 16, color: Colors.black54)),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        childAspectRatio: isDesktop ? 0.65 : 0.55,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final book = filtered[index];
        return _buildBookCard(book);
      },
    );
  }

  List<String> _getRecommendedDomains(String? faculty) {
    if (faculty == null) return [];
    
    switch (faculty) {
      case 'FTMK':
      case 'FAIX':
        return ['Computer Science & IT', 'Mathematics & Sciences', 'Languages & Linguistics', 'Humanities & Social Sciences'];
      case 'FTKE':
      case 'FTKM':
      case 'FTKEK':
      case 'FTKIP':
        return ['Engineering & Engineering Technology', 'Mathematics & Sciences', 'Languages & Linguistics', 'Humanities & Social Sciences'];
      case 'FPTT':
        return ['Business & Technology Management', 'Mathematics & Sciences', 'Languages & Linguistics', 'Humanities & Social Sciences'];
      case 'IPTK':
        return ['Business & Technology Management', 'Mathematics & Sciences', 'Research Methodology'];
      case 'SPAB':
        return ['Languages & Linguistics', 'Humanities & Social Sciences'];
      default:
        return [];
    }
  }

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

  Widget _buildBookCard(TextbookModel book) {
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextbookDetailsPage(textbook: book),
          ),
        ).then((_) => _fetchUserLists());
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: book.imageUrl != null
                  ? Image.network(
                      book.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black12,
                      child: const Center(child: Icon(Icons.menu_book, color: Colors.white, size: 50)),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Condition
                Text(
                  _getConditionText(book.conditionScore),
                  style: const TextStyle(color: Color(0xFFD84315), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // Title
                Text(
                  book.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  'RM ${book.listingPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                // Icons (Bag and Heart)
                SizedBox(
                  height: 48,
                  child: Builder(
                    builder: (context) {
                      final isOwnBook = AuthService().currentUser?.id == book.sellerID;
                      if (isOwnBook) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Your Listing', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
                        );
                      }
                      return Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _cartIds.contains(book.textbookID) ? Colors.green : const Color(0xFF023E8A), // Green if in cart
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              hoverColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              icon: Icon(
                                _cartIds.contains(book.textbookID) ? Icons.shopping_bag : Icons.shopping_bag_outlined, 
                                color: Colors.white, size: 20
                              ),
                              onPressed: () => _requireAuth(() => _toggleCart(book)),
                              tooltip: _cartIds.contains(book.textbookID) ? 'Remove from Bag' : 'Add to Bag',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            icon: Icon(
                              _wishlistIds.contains(book.textbookID) ? Icons.favorite : Icons.favorite_border,
                              color: _wishlistIds.contains(book.textbookID) ? Colors.red : Colors.black87,
                              size: 24
                            ),
                            onPressed: () => _requireAuth(() => _toggleWishlist(book)),
                            tooltip: _wishlistIds.contains(book.textbookID) ? 'Remove from Wishlist' : 'Add to Wishlist',
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSidePanel() {
    bool isWishlist = _activeSidePanel == 'wishlist';
    return Drawer(
      width: 400,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isWishlist ? 'Wishlist' : 'Shopping Bag',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          // Body
          Expanded(
            child: (isWishlist ? _isWishlistLoading : _isCartLoading)
              ? const Center(child: CircularProgressIndicator())
              : (isWishlist ? _wishlistBooks : _cartBooks).isEmpty
                ? _buildEmptyState(isWishlist)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: (isWishlist ? _wishlistBooks : _cartBooks).length,
                    itemBuilder: (context, index) {
                      final book = (isWishlist ? _wishlistBooks : _cartBooks)[index];
                      return InkWell(
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TextbookDetailsPage(textbook: book),
                            ),
                          ).then((_) {
                            Navigator.pop(context); // Close side panel when popping back so it doesn't show old state
                            _fetchUserLists(); // Or just fetch lists
                          });
                        },
                        child: _buildSidePanelItem(book, isWishlist),
                      );
                    },
                  ),
          ),
          
          if (!isWishlist && _cartBooks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        'RM ${_cartBooks.where((b) => _selectedCartIds.contains(b.textbookID)).fold(0.0, (sum, b) => sum + b.listingPrice).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _selectedCartIds.isEmpty ? null : () async {
                      final selectedBooks = _cartBooks.where((b) => _selectedCartIds.contains(b.textbookID)).toList();
                      final total = selectedBooks.fold(0.0, (sum, b) => sum + b.listingPrice);
                      
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutPage(
                            selectedBooks: selectedBooks,
                            totalPrice: total,
                          ),
                        ),
                      );
                      
                      // If checkout was successful, refresh the lists
                      if (result == true) {
                        setState(() {
                          _selectedCartIds.clear();
                        });
                        _fetchUserLists();
                        _fetchBooks(); // Refresh browse grid to remove sold items
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF023E8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text('Checkout (${_selectedCartIds.length} items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isWishlist) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isWishlist ? Icons.favorite_border : Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.black26,
            ),
            const SizedBox(height: 40),
            if (isWishlist) ...[
              const Text(
                'Looks like you don\'t have anything saved',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'A space for the books you\'ve saved.\nCome back anytime to keep track of the books you\'re eyeing.',
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text(
                'No products in the bag',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Browse our catalog and add items\nto your bag to check out.',
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanelItem(TextbookModel book, bool isWishlist) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWishlist)
            Checkbox(
              value: _selectedCartIds.contains(book.textbookID),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedCartIds.add(book.textbookID);
                  } else {
                    _selectedCartIds.remove(book.textbookID);
                  }
                });
              },
              activeColor: const Color(0xFF023E8A),
            ),
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: book.imageUrl != null
                ? Image.network(book.imageUrl!, width: 80, height: 100, fit: BoxFit.cover)
                : Container(width: 80, height: 100, color: Colors.black12, child: const Icon(Icons.menu_book, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Condition: ${_getConditionText(book.conditionScore)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                Text('Seller: ${book.seller?.fullName ?? 'Unknown'}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 8),
                Text('RM ${book.listingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF023E8A), fontSize: 16)),
              ],
            ),
          ),
          // Action Buttons
            Builder(
              builder: (context) {
                final isOwnBook = AuthService().currentUser?.id == book.sellerID;
                return Column(
                  children: [
                    IconButton(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        if (isWishlist) {
                          _toggleWishlist(book);
                        } else {
                          _toggleCart(book);
                        }
                      },
                      tooltip: 'Remove',
                    ),
                    if (isWishlist && !isOwnBook)
                      IconButton(
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        icon: Icon(
                          _cartIds.contains(book.textbookID) ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                          color: _cartIds.contains(book.textbookID) ? Colors.green : const Color(0xFF023E8A)
                        ),
                        onPressed: () => _toggleCart(book),
                        tooltip: _cartIds.contains(book.textbookID) ? 'Remove from Bag' : 'Add to Bag',
                      ),
                  ],
                );
              }
            )
        ],
      ),
    );

  }
}
