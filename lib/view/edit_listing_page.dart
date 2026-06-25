import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/textbook_service.dart';
import '../services/notification_service.dart';
import '../models/textbook_model.dart';

class EditListingPage extends StatefulWidget {
  final TextbookModel textbook;
  final VoidCallback onBack;
  final VoidCallback? onSubmitted;
  final String? title;
  final Widget? extraAction;
  final bool isAdminEdit;
  const EditListingPage({
    super.key, 
    required this.textbook, 
    required this.onBack, 
    this.onSubmitted,
    this.title, 
    this.extraAction, 
    this.isAdminEdit = false
  });

  @override
  State<EditListingPage> createState() => EditListingPageState();
}

class EditListingPageState extends State<EditListingPage> {
  final TextbookService _textbookService = TextbookService();
  final NotificationService _notificationService = NotificationService();
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
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final book = widget.textbook;
    _titleController.text = book.title;
    _editionController.text = book.edition?.toString() ?? '';
    _originalPriceController.text = book.originalPrice.toStringAsFixed(2);
    _sellingPriceController.text = book.listingPrice.toStringAsFixed(2);
    _descriptionController.text = book.description ?? '';
    
    _selectedFaculty = book.faculty;
    _selectedDomain = book.domain;
    _selectedStudyLevel = book.studyLevel;
    _isLatestEdition = book.isLatestEdition;
    _existingImageUrl = book.imageUrl;
    
    // Map condition score to condition string
    switch (book.conditionScore) {
      case 5: _selectedCondition = 'Brand New'; break;
      case 4: _selectedCondition = 'Like New'; break;
      case 3: _selectedCondition = 'Good'; break;
      case 2: _selectedCondition = 'Acceptable'; break;
    }
  }

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

  bool _hasChanges() {
    final book = widget.textbook;
    if (_titleController.text.trim() != book.title) return true;
    if (_editionController.text.trim() != (book.edition?.toString() ?? '')) return true;
    if ((double.tryParse(_originalPriceController.text) ?? 0.0) != book.originalPrice) return true;
    if ((double.tryParse(_sellingPriceController.text) ?? 0.0) != book.listingPrice) return true;
    if (_descriptionController.text.trim() != (book.description ?? '')) return true;
    
    if (_selectedFaculty != book.faculty) return true;
    if (_selectedDomain != book.domain) return true;
    if (_selectedStudyLevel != book.studyLevel) return true;
    if (_isLatestEdition != book.isLatestEdition) return true;
    
    String originalCondition = '';
    switch (book.conditionScore) {
      case 5: originalCondition = 'Brand New'; break;
      case 4: originalCondition = 'Like New'; break;
      case 3: originalCondition = 'Good'; break;
      case 2: originalCondition = 'Acceptable'; break;
    }
    if (_selectedCondition != originalCondition) return true;
    
    if (_imageBytes != null) return true;
    
    return false;
  }

  void handleBack() {
    if (_hasChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('You have unsaved changes. Are you sure you want to go back and discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onBack();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Discard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      widget.onBack();
    }
  }

  Future<void> _updateListing() async {
    if (!_hasChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes detected.')));
      return;
    }

    if (_titleController.text.isEmpty || _selectedDomain == null || _editionController.text.isEmpty ||
        _selectedCondition == null || _originalPriceController.text.isEmpty || _sellingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
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
      final _textbookService = TextbookService();
      
      String? newImageUrl;
      
      // 1. Upload new Image if picked
      if (_imageBytes != null && _imageExt != null) {
        final fileName = 'book_${DateTime.now().millisecondsSinceEpoch}.$_imageExt';
        newImageUrl = await _textbookService.uploadImage(fileName, _imageBytes!, _imageExt!);
        
        // Delete old image if it exists
        if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
          await _textbookService.deleteImage(_existingImageUrl!);
        }
      }

      // 2. Update DB
      final updates = {
        'title': _titleController.text.trim(),
        'domain': _selectedDomain,
        'faculty': _selectedFaculty,
        'studyLevel': _selectedStudyLevel,
        'edition': int.tryParse(_editionController.text.trim()),
        'conditionScore': _getConditionScore(_selectedCondition),
        'originalPrice': double.tryParse(_originalPriceController.text) ?? 0.0,
        'listingPrice': double.tryParse(_sellingPriceController.text) ?? 0.0,
        'isLatestEdition': _isLatestEdition,
        'description': _descriptionController.text.trim(),
        if (newImageUrl != null) 'image_url': newImageUrl,
      };

      if (!widget.isAdminEdit) {
        updates['status'] = 'Pending Approval';
        updates['rejectionReason'] = null;
      } else if (widget.textbook.status == 'Pending Edit') {
        updates['status'] = 'Available';
      }

      await _textbookService.updateTextbook(widget.textbook.textbookID, updates);

      if (!widget.isAdminEdit) {
        _notificationService.sendAdminNotification(
          title: 'Listing Resubmitted',
          message: 'A seller has resubmitted "${widget.textbook.title}" for review.',
          type: 'listing_submitted',
        );
      } else if (widget.textbook.status == 'Pending Edit') {
        _notificationService.sendNotification(
          userId: widget.textbook.sellerID,
          title: 'Book Available',
          message: 'Your book "${widget.textbook.title}" is now Live and Available!',
          type: 'book_available',
          referenceId: widget.textbook.textbookID.toString(),
        );
      }

      if (mounted) {
        if (widget.isAdminEdit) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved successfully.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing resubmitted for review!')));
          widget.onSubmitted?.call();
          widget.onBack();
        }
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
              if (widget.title != null) ...[
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
                    const SizedBox(width: 8),
                    Text(widget.title!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
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
                      image: _imageBytes != null 
                          ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) 
                          : (_existingImageUrl != null ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover) : null),
                    ),
                    child: _imageBytes == null && _existingImageUrl == null 
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.black38),
                              SizedBox(height: 16),
                              Text(
                                'Click to upload textbook image',
                                style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ) 
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.edit_outlined, size: 48, color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Tap to change image',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
              if (widget.extraAction != null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateListing,
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
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: widget.extraAction!,
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateListing,
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
                            'Save Changes',
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
