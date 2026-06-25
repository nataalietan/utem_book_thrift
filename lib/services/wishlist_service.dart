import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/textbook_model.dart';
import 'auth_service.dart';

class WishlistService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Get all textbooks in the user's wishlist
  Future<List<TextbookModel>> getWishlist() async {
    final user = _authService.currentUser;
    if (user == null) return [];

    try {
      final data = await _client
          .from('WISHLIST')
          .select('textbookID, TEXTBOOK(*, USER:sellerID(*))')
          .eq('userID', user.id)
          .order('created_at', ascending: false);

      List<TextbookModel> textbooks = [];
      for (var item in data) {
        if (item['TEXTBOOK'] != null && item['TEXTBOOK']['status'] == 'Available') {
          textbooks.add(TextbookModel.fromJson(item['TEXTBOOK']));
        }
      }
      return textbooks;
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      return [];
    }
  }

  // Check if a textbook is in the user's wishlist
  Future<bool> isInWishlist(dynamic textbookID) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final data = await _client
          .from('WISHLIST')
          .select('wishlistID')
          .eq('userID', user.id)
          .eq('textbookID', textbookID);
      
      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking wishlist status: $e');
      return false;
    }
  }

  // Toggle wishlist status
  Future<bool> toggleWishlist(dynamic textbookID) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('Must be logged in to manage wishlist');

    try {
      final isCurrentlyInWishlist = await isInWishlist(textbookID);
      
      if (isCurrentlyInWishlist) {
        // Remove from wishlist
        await _client
            .from('WISHLIST')
            .delete()
            .eq('userID', user.id)
            .eq('textbookID', textbookID);
        return false;
      } else {
        // Add to wishlist
        await _client
            .from('WISHLIST')
            .insert({
              'userID': user.id,
              'textbookID': textbookID,
            });
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      rethrow;
    }
  }
}
