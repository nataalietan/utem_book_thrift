import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/textbook_service.dart';
import '../services/notification_service.dart';
import '../models/textbook_model.dart';

class AddListingPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onSubmitted;
  const AddListingPage({super.key, required this.onBack, this.onSubmitted});

  @override
  State<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<AddListingPage> {
  final TextbookService _textbookService = TextbookService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final _titleController = TextEditingController();
  final _editionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedFaculty;
  String? _selectedDomain;
  String? _selectedCondition;
  String? _selectedStudyLevel;
  bool _isLatestEdition = false;
  
  bool _isLoading = false;

  final List<String> _faculties = ['FTMK', 'FTKE', 'FTKM', 'FTKEK', 'FAIX', 'FPTT', 'FTKIP', 'SPAB', 'IPTK'];
  final List<String> _domains = [
    'Computer Science & IT',
    'Engineering & Engineering Technology',
    'Business & Technology Management',
    'Mathematics & Sciences',
    'Humanities & Social Sciences',
    'Languages & Linguistics',
    'Research Methodology'
  ];
  final List<String> _studyLevels = ['Diploma', 'Degree', 'Master\'s', 'PhD'];
  final List<String> _conditions = ['Brand New', 'Like New', 'Good', 'Acceptable'];
  
  Uint8List? _imageBytes;
  String? _imageExt;

  @override
  void dispose() {
    _titleController.dispose();
    _editionController.dispose();
    _originalPriceController.dispose();
    _sellingPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      setState(() {
        _imageBytes = bytes;
        _imageExt = ext;
      });
    }
  }
  
  int _getConditionScore(String? condition) {
    switch (condition) {
      case 'Brand New': return 5;
      case 'Like New': return 4;
      case 'Good': return 3;
      case 'Acceptable': return 2;
      default: return 0;
    }
  }

  Future<void> _submitListing() async {
    if (_titleController.text.isEmpty || _selectedDomain == null || _editionController.text.isEmpty ||
        _selectedCondition == null || _originalPriceController.text.isEmpty || _sellingPriceController.text.isEmpty ||
        _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields and upload an image.')));
      return;
    }

    final double originalPrice = double.tryParse(_originalPriceController.text) ?? 0.0;
    final double listingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;

    if (listingPrice > originalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selling price cannot exceed the original price.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final _authService = AuthService();
      final _textbookService = TextbookService();
      
      final user = _authService.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Upload Image
      final fileName = 'book_${DateTime.now().millisecondsSinceEpoch}.$_imageExt';
      final imageUrl = await _textbookService.uploadImage(fileName, _imageBytes!, _imageExt!);

      // 2. Insert into DB
      final textbook = TextbookModel(
        textbookID: null,
        sellerID: user.id,
        title: _titleController.text.trim(),
        domain: _selectedDomain!,
        faculty: _selectedFaculty,
        studyLevel: _selectedStudyLevel,
        edition: int.tryParse(_editionController.text.trim()),
        conditionScore: _getConditionScore(_selectedCondition),
        originalPrice: double.tryParse(_originalPriceController.text) ?? 0.0,
        listingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
        isLatestEdition: _isLatestEdition,
        status: 'Pending Approval',
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _textbookService.insertTextbook(textbook);

      _notificationService.sendAdminNotification(
        title: 'New Listing Submitted',
        message: 'A seller has submitted "${textbook.title}" for review.',
        type: 'listing_submitted',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing submitted for review!')));
        widget.onSubmitted?.call();
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Your listing will be reviewed by an administrator before it is published. Please upload a clear picture of the book cover showing all relevant info.',
                        style: TextStyle(color: Colors.blue[800], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 320,
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12, style: BorderStyle.solid),
                      image: _imageBytes != null ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) : null,
                    ),
                    child: _imageBytes == null ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.black38),
                        SizedBox(height: 16),
                        Text(
                          'Click to upload textbook image',
                          style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ) : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Note: Buyers will be able to tap on the image to view the full, uncropped picture.',
                  style: TextStyle(color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildLabel('Book Title *'),
              _buildTextField(controller: _titleController, hint: 'Enter book title'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Faculty'),
                        _buildDropdown(
                          value: _selectedFaculty,
                          items: _faculties,
                          hint: 'Select Faculty',
                          onChanged: (val) => setState(() => _selectedFaculty = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Study Level'),
                        _buildDropdown(
                          value: _selectedStudyLevel,
                          items: _studyLevels,
                          hint: 'Select Level',
                          onChanged: (val) => setState(() => _selectedStudyLevel = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('Domain *'),
              _buildDropdown(
                value: _selectedDomain,
                items: _domains,
                hint: 'Select Domain',
                onChanged: (val) => setState(() => _selectedDomain = val),
              ),
              const SizedBox(height: 16),

              _buildLabel('Edition *'),
              _buildTextField(controller: _editionController, hint: 'Enter edition number (e.g. 1, 2)', isNumber: true),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Is this the latest edition?', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    Switch(
                      value: _isLatestEdition,
                      onChanged: (val) => setState(() => _isLatestEdition = val),
                      activeColor: const Color(0xFF023E8A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Condition *'),
              _buildDropdown(
                value: _selectedCondition,
                items: _conditions,
                hint: 'Select condition',
                onChanged: (val) {
                  setState(() {
                    _selectedCondition = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Original Price (RM) *'),
                        _buildTextField(controller: _originalPriceController, hint: '0.00', isNumber: true, isDecimal: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Selling Price (RM) *'),
                        _buildTextField(controller: _sellingPriceController, hint: '0.00', isNumber: true, isDecimal: true),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              


              _buildLabel('Description (Optional)'),
              _buildTextField(controller: _descriptionController, hint: 'Describe any damages or highlights', maxLines: 3),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF023E8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text(
                          'Submit for Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumber = false,
    bool isDecimal = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.numberWithOptions(decimal: isDecimal) : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(isDecimal ? r'[0-9.]' : r'[0-9]'))] : null,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.black26, fontSize: 14)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint, style: const TextStyle(fontSize: 14, color: Colors.black38)),
            ),
            ...items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14, color: Colors.black87)),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
