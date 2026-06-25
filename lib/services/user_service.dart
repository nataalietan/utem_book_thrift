import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> insertUser(UserModel user) async {
    await _client.from('USER').insert(user.toJson());
  }

  Future<void> upsertUser(UserModel user) async {
    await _client.from('USER').upsert(user.toJson());
  }

  Future<UserModel?> fetchUser(String userId) async {
    final data = await _client.from('USER').select('*').eq('userID', userId).maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }
}
