import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carbon_chain/services/auth_service.dart';
import 'package:carbon_chain/screens/home_screen.dart';
import 'package:carbon_chain/screens/admin_dashboard_screen.dart';
import 'package:carbon_chain/screens/pending_approval_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _truckController = TextEditingController();
  final _companyController = TextEditingController();
  final _companyNameController = TextEditingController(); // for owner

  DateTime? _dob;
  bool _loading = false;
  String? _error;

  // Company search
  List<Map<String, dynamic>> _companySuggestions = [];
  Map<String, dynamic>? _selectedCompany;
  Timer? _searchDebounce;

  bool get _isDriver => widget.role == 'driver';

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _truckController.dispose();
    _companyController.dispose();
    _companyNameController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF1DB954))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _onCompanySearch(String query) {
    _searchDebounce?.cancel();
    _selectedCompany = null;
    if (query.trim().isEmpty) {
      setState(() => _companySuggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await AuthService.searchCompanies(query);
      if (mounted) setState(() => _companySuggestions = results);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Enter your name'); return; }
    if (_dob == null) { setState(() => _error = 'Select your date of birth'); return; }
    if (location.isEmpty) { setState(() => _error = 'Enter your location'); return; }

    if (_isDriver) {
      if (_truckController.text.trim().isEmpty) { setState(() => _error = 'Enter your truck number'); return; }
      if (_selectedCompany == null) { setState(() => _error = 'Select your company from the list'); return; }
    } else {
      if (_companyNameController.text.trim().isEmpty) { setState(() => _error = 'Enter your company name'); return; }
    }

    setState(() { _loading = true; _error = null; });
    try {
      if (_isDriver) {
        await AuthService.createDriverProfile(
          name: name,
          dob: _dob!.toIso8601String().substring(0, 10),
          location: location,
          truckNumber: _truckController.text.trim(),
          companyId: _selectedCompany!['id'] as String,
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PendingApprovalScreen()));
      } else {
        await AuthService.createOwnerProfile(
          name: name,
          dob: _dob!.toIso8601String().substring(0, 10),
          location: location,
          companyName: _companyNameController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to save. Try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block back button — driver must complete profile
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1923),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(_isDriver ? Icons.drive_eta_outlined : Icons.business_outlined,
                    color: _isDriver ? const Color(0xFF1DB954) : Colors.blueAccent, size: 44),
                const SizedBox(height: 14),
                Text(
                  _isDriver ? 'Driver Profile' : 'Owner Profile',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text('Fill in your details to continue', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 28),

                _field(_nameController, 'Full Name', Icons.person_outline),
                const SizedBox(height: 14),

                // DOB
                GestureDetector(
                  onTap: _pickDob,
                  child: _container(Row(children: [
                    Icon(Icons.cake_outlined, color: Colors.white.withOpacity(0.4), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _dob == null ? 'Date of Birth' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                      style: TextStyle(color: _dob == null ? Colors.white38 : Colors.white, fontSize: 15),
                    ),
                  ])),
                ),
                const SizedBox(height: 14),

                _field(_locationController, 'City / Location', Icons.location_on_outlined),
                const SizedBox(height: 14),

                if (_isDriver) ...[
                  _field(_truckController, 'Truck Number (e.g. MH12AB1234)', Icons.local_shipping_outlined),
                  const SizedBox(height: 14),

                  // Company search
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: _companyController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: _onCompanySearch,
                      decoration: InputDecoration(
                        labelText: _selectedCompany != null
                            ? 'Company: ${_selectedCompany!['name']}'
                            : 'Search Company Name',
                        labelStyle: TextStyle(color: _selectedCompany != null ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.4)),
                        prefixIcon: Icon(Icons.business_outlined, color: Colors.white.withOpacity(0.4), size: 20),
                        suffixIcon: _selectedCompany != null
                            ? Icon(Icons.check_circle, color: const Color(0xFF1DB954))
                            : null,
                        filled: true, fillColor: const Color(0xFF1A1F2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _selectedCompany != null ? const Color(0xFF1DB954).withOpacity(0.5) : Colors.white.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1DB954))),
                      ),
                    ),
                    if (_companySuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(children: _companySuggestions.map((c) => ListTile(
                          leading: const Icon(Icons.business, color: Colors.blueAccent, size: 18),
                          title: Text(c['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          onTap: () {
                            setState(() {
                              _selectedCompany = c;
                              _companyController.text = c['name'] as String;
                              _companySuggestions = [];
                            });
                          },
                        )).toList()),
                      ),
                  ]),
                ] else ...[
                  _field(_companyNameController, 'Company Name', Icons.business_outlined),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ],
                const SizedBox(height: 28),

                SizedBox(height: 56, child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDriver ? const Color(0xFF1DB954) : Colors.blueAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                      : Text(_isDriver ? 'Send Join Request' : 'Create Company', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        filled: true, fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1DB954))),
      ),
    );
  }

  Widget _container(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}
