import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../models/textbook_model.dart';

class TextbookService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<TextbookModel>> fetchAvailableBooks() async {
    try {
      final data = await _client
          .from('TEXTBOOK')
          .select('*, USER(fullName)')
          .eq('status', 'Available')
          .eq('isArchived', false)
          .order('created_at', ascending: false);
      
      debugPrint('SUCCESS: Fetched ${data.length} available textbooks from Supabase!');
      return List<Map<String, dynamic>>.from(data).map((json) => TextbookModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ERROR fetching available textbooks with USER join: $e');
      // Fallback
      try {
        final data = await _client
            .from('TEXTBOOK')
            .select('*')
            .eq('status', 'Available')
            .order('created_at', ascending: false);
        debugPrint('SUCCESS (Fallback): Fetched ${data.length} available textbooks without USER join!');
        return List<Map<String, dynamic>>.from(data).map((json) => TextbookModel.fromJson(json)).toList();
      } catch (fallbackError) {
        debugPrint('CRITICAL ERROR fetching available textbooks: $fallbackError');
        return [];
      }
    }
  }

  Future<List<TextbookModel>> fetchAllBooks() async {
    try {
      final data = await _client.from('TEXTBOOK').select('*, USER(*)').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data).map((json) => TextbookModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ERROR fetching all inventory books: $e');
      return [];
    }
  }

  Future<List<TextbookModel>> fetchSellerBooks(String sellerId) async {
    try {
      final data = await _client.from('TEXTBOOK').select('*, USER(*)').eq('sellerID', sellerId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data).map((json) => TextbookModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ERROR fetching seller books: $e');
      return [];
    }
  }

  Future<void> insertTextbook(TextbookModel textbook) async {
    await _client.from('TEXTBOOK').insert(textbook.toJson());
  }

  Future<void> deleteTextbook(dynamic textbookId) async {
    await _client.from('TEXTBOOK').delete().eq('textbookID', textbookId);
  }

  Future<void> updateTextbookStatus(dynamic textbookId, String status) async {
    await _client.from('TEXTBOOK').update({'status': status}).eq('textbookID', textbookId);
  }

  Future<void> updateTextbook(dynamic textbookId, Map<String, dynamic> updates) async {
    await _client.from('TEXTBOOK').update(updates).eq('textbookID', textbookId);
  }

  Future<String> uploadImage(String fileName, Uint8List imageBytes, String extension) async {
    await _client.storage.from('textbooks').uploadBinary(
      fileName,
      imageBytes,
      fileOptions: FileOptions(contentType: 'image/$extension'),
    );
    return _client.storage.from('textbooks').getPublicUrl(fileName);
  }

  Future<String> uploadReceiptImage(String fileName, Uint8List imageBytes, String extension) async {
    await _client.storage.from('receipts').uploadBinary(
      fileName,
      imageBytes,
      fileOptions: FileOptions(contentType: 'image/$extension'),
    );
    return _client.storage.from('receipts').getPublicUrl(fileName);
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('textbooks');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final fileName = pathSegments.skip(bucketIndex + 1).join('/');
        await _client.storage.from('textbooks').remove([fileName]);
        debugPrint('SUCCESS: Deleted old image $fileName');
      }
    } catch (e) {
      debugPrint('ERROR deleting old image: $e');
    }
  }
}
