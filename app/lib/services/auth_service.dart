import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  /// Send OTP to phone number (format: +91XXXXXXXXXX)
  static Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  /// Verify OTP — returns true if successful
  static Future<bool> verifyOtp(String phone, String otp) async {
    final res = await _supabase.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
    return res.user != null;
  }

  /// Check if profile exists for current user
  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final res = await _supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return res;
  }

  /// Create profile on first login
  static Future<void> createProfile({
    required String name,
    required String dob,
    required String location,
    String role = 'driver',
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'phone': currentUser?.phone,
      'role': role,
      'dob': dob,
      'location': location,
    });
  }

  /// Get all trucks (for admin)
  static Future<List<Map<String, dynamic>>> getTrucks() async {
    final res = await _supabase
        .from('trucks')
        .select('*, profiles(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Get fleet CO₂ stats for admin dashboard
  static Future<Map<String, dynamic>> getFleetStats() async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();

    Future<double> sumCarbon(String since) async {
      final res = await _supabase
          .from('emissions')
          .select('carbon_kg')
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double total = 0.0;
      for (final r in list) {
        total += (r['carbon_kg'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    }

    final results = await Future.wait([
      sumCarbon(dayStart),
      sumCarbon(weekStart),
      sumCarbon(monthStart),
      sumCarbon(yearStart),
    ]);

    return {
      'day': results[0],
      'week': results[1],
      'month': results[2],
      'annual': results[3],
    };
  }

  /// Get CO₂ stats per truck
  static Future<List<Map<String, dynamic>>> getTruckStats() async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();

    final trucks = await getTrucks();

    Future<double> truckCarbon(String truckId, String since) async {
      final res = await _supabase
          .from('emissions')
          .select('carbon_kg')
          .eq('truck_id', truckId)
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double total = 0.0;
      for (final r in list) {
        total += (r['carbon_kg'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    }

    final result = <Map<String, dynamic>>[];
    for (final truck in trucks) {
      final id = truck['id'] as String;
      final stats = await Future.wait([
        truckCarbon(id, dayStart),
        truckCarbon(id, weekStart),
        truckCarbon(id, monthStart),
        truckCarbon(id, yearStart),
      ]);
      result.add({
        ...truck,
        'day': stats[0],
        'week': stats[1],
        'month': stats[2],
        'annual': stats[3],
      });
    }
    return result;
  }

  /// Get trip history for a specific truck
  static Future<List<Map<String, dynamic>>> getTruckTrips(String truckId) async {
    final res = await _supabase
        .from('emissions')
        .select()
        .eq('truck_id', truckId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
