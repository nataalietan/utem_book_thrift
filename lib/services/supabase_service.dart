import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  // Example method to fetch books
  Future<List<dynamic>> fetchBooks() async {
    try {
      final response = await supabase.from('TEXTBOOK').select();
      return response;
    } catch (e) {
      print('Error fetching books: $e');
      return [];
    }
  }
}
