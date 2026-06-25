import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  await dotenv.load(fileName: ".env");

  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );

  try {
    print('Fetching available books...');
    final data = await supabase
        .from('TEXTBOOK')
        .select('*, USER(fullName)')
        .eq('status', 'Available')
        .order('createdAt', ascending: false);
    print('Fetched \${data.length} books.');
    print(data);
  } catch (e) {
    print('Error with createdAt: \$e');
  }

  try {
    print('Fetching with created_at...');
    final data = await supabase
        .from('TEXTBOOK')
        .select('*, USER(fullName)')
        .eq('status', 'Available')
        .order('created_at', ascending: false);
    print('Fetched \${data.length} books.');
    print(data);
  } catch (e) {
    print('Error with created_at: \$e');
  }
  exit(0);
}
