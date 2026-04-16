import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  static Future<bool> verifyOtp(String phone, String otp) async {
    final res = await _supabase.auth.verifyOTP(
      phone: phone, token: otp, type: OtpType.sms,
    );
    return res.user != null;
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      return await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
    } catch (_) { return null; }
  }

  /// Create driver profile — does NOT navigate, caller handles routing
  static Future<void> createDriverProfile({
    required String name,
    required String dob,
    required String location,
    required String truckNumber,
    required String companyId,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'phone': currentUser?.phone,
      'role': 'driver',
      'dob': dob,
      'location': location,
      'truck_number': truckNumber,
      'company_id': companyId,
      'status': 'pending',
    });
    // Send join request
    await _supabase.from('driver_requests').upsert({
      'driver_id': uid,
      'company_id': companyId,
      'status': 'pending',
    });
  }

  /// Create owner profile and company
  static Future<void> createOwnerProfile({
    required String name,
    required String dob,
    required String location,
    required String companyName,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    // Create profile first
    await _supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'phone': currentUser?.phone,
      'role': 'admin',
      'dob': dob,
      'location': location,
      'status': 'accepted',
    });
    // Create company
    final company = await _supabase.from('companies').insert({
      'name': companyName,
      'owner_id': uid,
    }).select().single();
    // Link company to profile
    await _supabase.from('profiles').update({'company_id': company['id']}).eq('id', uid);
  }

  /// Search companies by name prefix
  static Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await _supabase
        .from('companies')
        .select('id, name')
        .ilike('name', '$query%')
        .limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Get driver's join request status
  static Future<String?> getDriverRequestStatus() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _supabase
          .from('driver_requests')
          .select('status')
          .eq('driver_id', uid)
          .maybeSingle();
      return res?['status'] as String?;
    } catch (_) { return null; }
  }

  /// Owner: get pending driver requests for their company
  static Future<List<Map<String, dynamic>>> getPendingRequests(String companyId) async {
    final res = await _supabase
        .from('driver_requests')
        .select('*, profiles(name, phone, truck_number)')
        .eq('company_id', companyId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Owner: accept or reject a driver request
  static Future<void> respondToRequest(String requestId, String driverId, bool accept) async {
    final status = accept ? 'accepted' : 'rejected';
    await _supabase.from('driver_requests').update({'status': status}).eq('id', requestId);
    await _supabase.from('profiles').update({'status': status}).eq('id', driverId);
  }

  /// Get all drivers in a company
  static Future<List<Map<String, dynamic>>> getCompanyDrivers(String companyId) async {
    final res = await _supabase
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .eq('role', 'driver')
        .eq('status', 'accepted')
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Get fleet CO₂ stats for a company
  static Future<Map<String, dynamic>> getFleetStats(String companyId) async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();

    Future<double> sumCarbon(String since) async {
      final res = await _supabase
          .from('emissions')
          .select('carbon_kg')
          .eq('company_id', companyId)
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double total = 0.0;
      for (final r in list) { total += (r['carbon_kg'] as num?)?.toDouble() ?? 0.0; }
      return total;
    }

    final results = await Future.wait([
      sumCarbon(dayStart), sumCarbon(weekStart), sumCarbon(monthStart), sumCarbon(yearStart),
    ]);
    return {'day': results[0], 'week': results[1], 'month': results[2], 'annual': results[3]};
  }

  /// Get per-driver CO₂ stats for a company
  static Future<List<Map<String, dynamic>>> getDriverStats(String companyId) async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();
    final drivers = await getCompanyDrivers(companyId);

    Future<double> driverCarbon(String driverId, String since) async {
      final res = await _supabase
          .from('emissions')
          .select('carbon_kg')
          .eq('user_id', driverId)
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double total = 0.0;
      for (final r in list) { total += (r['carbon_kg'] as num?)?.toDouble() ?? 0.0; }
      return total;
    }

    Future<bool> hasOverspeeding(String driverId) async {
      // Check if any trip had max_speed > 120 (stored in emissions if we add it)
      // For now check if any emission record has a note about overspeeding
      return false; // placeholder — implement when speed tracking is added to emissions
    }

    final result = <Map<String, dynamic>>[];
    for (final driver in drivers) {
      final id = driver['id'] as String;
      final stats = await Future.wait([
        driverCarbon(id, dayStart),
        driverCarbon(id, weekStart),
        driverCarbon(id, monthStart),
        driverCarbon(id, yearStart),
      ]);
      result.add({
        ...driver,
        'day': stats[0], 'week': stats[1], 'month': stats[2], 'annual': stats[3],
      });
    }
    return result;
  }

  /// Get driver's own trip history
  static Future<List<Map<String, dynamic>>> getMyTrips() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final res = await _supabase
        .from('emissions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Get driver's monthly stats
  static Future<Map<String, dynamic>> getMyStats() async {
    final uid = currentUser?.id;
    if (uid == null) return {};
    final now = DateTime.now().toUtc();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    Future<Map<String, double>> stats(String since) async {
      final res = await _supabase
          .from('emissions')
          .select('carbon_kg, distance, idle_time')
          .eq('user_id', uid)
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double carbon = 0, distance = 0, idle = 0;
      for (final r in list) {
        carbon += (r['carbon_kg'] as num?)?.toDouble() ?? 0;
        distance += (r['distance'] as num?)?.toDouble() ?? 0;
        idle += (r['idle_time'] as num?)?.toDouble() ?? 0;
      }
      return {'carbon': carbon, 'distance': distance, 'idle': idle, 'trips': list.length.toDouble()};
    }

    final results = await Future.wait([stats(dayStart), stats(weekStart), stats(monthStart)]);
    return {'day': results[0], 'week': results[1], 'month': results[2]};
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Switch role between driver and admin (for testing/demo)
  static Future<void> switchRole(String newRole) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').update({'role': newRole, 'status': 'accepted'}).eq('id', uid);
  }
}
