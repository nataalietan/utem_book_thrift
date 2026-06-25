import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/textbook_model.dart';
import 'auth_service.dart';

class CartService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Get all textbooks in the user's cart
  Future<List<TextbookModel>> getCart() async {
    final user = _authService.currentUser;
    if (user == null) return [];

    try {
      final data = await _client
          .from('CART')
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
      debugPrint('Error fetching cart: $e');
      return [];
    }
  }

  // Check if a textbook is in the user's cart
  Future<bool> isInCart(dynamic textbookID) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final data = await _client
          .from('CART')
          .select('cartID')
          .eq('userID', user.id)
          .eq('textbookID', textbookID);
      
      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking cart status: $e');
      return false;
    }
  }

  // Toggle cart status
  Future<bool> toggleCart(dynamic textbookID) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('Must be logged in to manage cart');

    try {
      final isCurrentlyInCart = await isInCart(textbookID);
      
      if (isCurrentlyInCart) {
        // Remove from cart
        await _client
            .from('CART')
            .delete()
            .eq('userID', user.id)
            .eq('textbookID', textbookID);
        return false;
      } else {
        // Add to cart
        await _client
            .from('CART')
            .insert({
              'userID': user.id,
              'textbookID': textbookID,
            });
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling cart: $e');
      rethrow;
    }
  }
}
