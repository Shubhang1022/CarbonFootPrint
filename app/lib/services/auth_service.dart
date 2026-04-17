import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  // ── Phone Auth ─────────────────────────────────────────────────────────────
  static Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  static Future<bool> verifyOtp(String phone, String otp) async {
    final res = await _supabase.auth.verifyOTP(phone: phone, token: otp, type: OtpType.sms);
    return res.user != null;
  }

  // ── Email Auth ─────────────────────────────────────────────────────────────
  static Future<void> signUpWithEmail(String email, String password) async {
    // Use OTP flow — sends 6-digit code to email
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  static Future<bool> signInWithEmail(String email, String password) async {
    // Use OTP flow for sign in too
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
    return true; // OTP sent
  }

  static Future<bool> verifyEmailOtp(String email, String otp) async {
    final res = await _supabase.auth.verifyOTP(email: email, token: otp, type: OtpType.email);
    return res.user != null;
  }

  static Future<bool> phoneAlreadyExists(String phone) async {
    try {
      final res = await _supabase.from('profiles').select('id').eq('phone', phone).maybeSingle();
      return res != null;
    } catch (_) { return false; }
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try { return await _supabase.from('profiles').select().eq('id', uid).maybeSingle(); }
    catch (_) { return null; }
  }

  static Future<void> createDriverProfile({
    required String name, required String dob, required String location,
    required String truckNumber, required String companyId, String? phone,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').upsert({
      'id': uid, 'name': name, 'phone': phone ?? currentUser?.phone,
      'role': 'driver', 'dob': dob, 'location': location,
      'truck_number': truckNumber, 'company_id': companyId, 'status': 'pending',
    });
    await _supabase.from('driver_requests').upsert({'driver_id': uid, 'company_id': companyId, 'status': 'pending'});
  }

  static Future<void> createOwnerProfile({
    required String name, required String dob, required String location,
    required String companyName, String? phone,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').upsert({
      'id': uid, 'name': name, 'phone': phone ?? currentUser?.phone,
      'role': 'admin', 'dob': dob, 'location': location, 'status': 'accepted',
    });
    String companyId;
    try {
      final company = await _supabase.from('companies').insert({'name': companyName, 'owner_id': uid, 'owner_email': currentUser?.email}).select().single();
      companyId = company['id'] as String;
    } catch (_) {
      final existing = await _supabase.from('companies').select('id').eq('name', companyName).maybeSingle();
      if (existing == null) rethrow;
      companyId = existing['id'] as String;
      await _supabase.from('companies').update({'owner_id': uid}).eq('id', companyId);
    }
    await _supabase.from('profiles').update({'company_id': companyId}).eq('id', uid);
  }

  // ── Company ────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await _supabase.from('companies').select('id, name').ilike('name', '$query%').limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  // ── Driver Requests ────────────────────────────────────────────────────────
  static Future<String?> getDriverRequestStatus() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _supabase.from('driver_requests').select('status').eq('driver_id', uid).maybeSingle();
      return res?['status'] as String?;
    } catch (_) { return null; }
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests(String companyId) async {
    final res = await _supabase.from('driver_requests')
        .select('*, profiles(name, phone, truck_number)')
        .eq('company_id', companyId).eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> respondToRequest(String requestId, String driverId, bool accept) async {
    final status = accept ? 'accepted' : 'rejected';
    await _supabase.from('driver_requests').update({'status': status}).eq('id', requestId);
    await _supabase.from('profiles').update({'status': status}).eq('id', driverId);
  }

  // ── Fleet Stats ────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCompanyDrivers(String companyId) async {
    final res = await _supabase.from('profiles').select()
        .eq('company_id', companyId).eq('role', 'driver').eq('status', 'accepted').order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> getFleetStats(String companyId) async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();

    Future<double> sum(String since) async {
      final res = await _supabase.from('emissions').select('carbon_kg').eq('company_id', companyId).gte('created_at', since);
      double t = 0;
      for (final r in List<Map<String, dynamic>>.from(res)) { t += (r['carbon_kg'] as num?)?.toDouble() ?? 0; }
      return t;
    }
    final r = await Future.wait([sum(dayStart), sum(weekStart), sum(monthStart), sum(yearStart)]);
    return {'day': r[0], 'week': r[1], 'month': r[2], 'annual': r[3]};
  }

  static Future<List<Map<String, dynamic>>> getDriverStats(String companyId) async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final yearStart = DateTime(now.year, 1, 1).toIso8601String();
    final drivers = await getCompanyDrivers(companyId);

    Future<double> dc(String driverId, String since) async {
      final res = await _supabase.from('emissions').select('carbon_kg').eq('user_id', driverId).gte('created_at', since);
      double t = 0;
      for (final r in List<Map<String, dynamic>>.from(res)) { t += (r['carbon_kg'] as num?)?.toDouble() ?? 0; }
      return t;
    }

    final result = <Map<String, dynamic>>[];
    for (final d in drivers) {
      final id = d['id'] as String;
      final s = await Future.wait([dc(id, dayStart), dc(id, weekStart), dc(id, monthStart), dc(id, yearStart)]);
      result.add({...d, 'day': s[0], 'week': s[1], 'month': s[2], 'annual': s[3]});
    }
    return result;
  }

  // ── Driver Dashboard ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMyTrips() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final res = await _supabase.from('emissions').select().eq('user_id', uid).order('created_at', ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> getMyStats() async {
    final uid = currentUser?.id;
    if (uid == null) return {};
    final now = DateTime.now().toUtc();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    Future<Map<String, double>> s(String since) async {
      final res = await _supabase.from('emissions').select('carbon_kg, distance, idle_time').eq('user_id', uid).gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res);
      double carbon = 0, distance = 0, idle = 0;
      for (final r in list) {
        carbon += (r['carbon_kg'] as num?)?.toDouble() ?? 0;
        distance += (r['distance'] as num?)?.toDouble() ?? 0;
        idle += (r['idle_time'] as num?)?.toDouble() ?? 0;
      }
      return {'carbon': carbon, 'distance': distance, 'idle': idle, 'trips': list.length.toDouble()};
    }
    final r = await Future.wait([s(dayStart), s(weekStart), s(monthStart)]);
    return {'day': r[0], 'week': r[1], 'month': r[2]};
  }

  // ── Misc ───────────────────────────────────────────────────────────────────
  static Future<void> signOut() async => await _supabase.auth.signOut();

  static Future<void> switchRole(String newRole) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').update({'role': newRole, 'status': 'accepted'}).eq('id', uid);
  }
}
