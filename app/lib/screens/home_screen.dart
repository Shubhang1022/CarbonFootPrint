
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/gps_tracker.dart';
import 'package:carbon_chain/services/trip_api_service.dart';
import 'package:carbon_chain/utils/location_permission.dart';
import 'package:carbon_chain/utils/app_strings.dart';
import 'package:carbon_chain/screens/result_screen.dart';
import 'package:carbon_chain/screens/history_screen.dart';
import 'package:carbon_chain/screens/driver_profile_screen.dart';

class TripState {
  bool isActive;
  double cumulativeDistanceM;
  int idleTimeSeconds;
  int ignitionTimeSeconds;
  String? fuelType;
  double? loadWeightKg;
  double? engineEfficiencyKmpl;

  TripState({
    this.isActive = false,
    this.cumulativeDistanceM = 0.0,
    this.idleTimeSeconds = 0,
    this.ignitionTimeSeconds = 0,
    this.fuelType,
    this.loadWeightKg,
    this.engineEfficiencyKmpl,
  });
}

class HomeScreen extends StatefulWidget {
  final GpsTracker? tracker;
  final Future<bool> Function(BuildContext)? permissionChecker;
  final TripApiService? apiService;

  const HomeScreen({super.key, this.tracker, this.permissionChecker, this.apiService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final GpsTracker _gpsTracker = widget.tracker ?? GpsTracker();
  late final TripApiService _apiService = widget.apiService ?? TripApiService();
  final TextEditingController _loadWeightController = TextEditingController();
  final TextEditingController _engineEffController = TextEditingController(text: '10');
  Timer? _uiTimer;
  Timer? _coachTimer;
  late AnimationController _pulseController;

  final TripState _tripState = TripState();
  String? _selectedFuelType;
  String? _fuelTypeError;
  String? _loadWeightError;
  String? _engineEffError;
  bool _isSubmitting = false;
  bool _isPaused = false;
  int _breakTimeSeconds = 0;
  double _currentSpeedKmh = 0.0;
  String _coachingTip = '';
  bool _isHindi = false;

  bool _isDemoRunning = false;
  Timer? _demoTimer;
  int _demoStep = 0;
  String _demoStatus = '';

  static const _demoDistanceSteps = [800.0, 1200.0, 950.0, 0.0, 0.0, 0.0, 0.0, 1100.0, 1400.0, 1300.0, 900.0, 0.0, 0.0, 0.0, 1750.0, 1200.0];
  static const _demoIdleSteps = [false, false, false, true, true, false, false, false, false, false, false, true, true, true, false, false];
  static const _demoPauseAt = 5;
  static const _demoResumeAt = 7;

  AppStrings get s => AppStrings(isHindi: _isHindi);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tripState.isActive) {
        setState(() {
          _tripState.cumulativeDistanceM = _gpsTracker.cumulativeDistanceM;
          _tripState.idleTimeSeconds = _gpsTracker.idleTimeSeconds;
          _tripState.ignitionTimeSeconds = _gpsTracker.ignitionTimeSeconds;
          _currentSpeedKmh = _gpsTracker.currentSpeedKmh;
          _isPaused = _gpsTracker.isPaused;
          _breakTimeSeconds = _gpsTracker.breakTimeSeconds +
              (_gpsTracker.isPaused && _gpsTracker.pausedAt != null
                  ? DateTime.now().difference(_gpsTracker.pausedAt!).inSeconds : 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _demoTimer?.cancel();
    _coachTimer?.cancel();
    _pulseController.dispose();
    _gpsTracker.stopTracking();
    _loadWeightController.dispose();
    _engineEffController.dispose();
    super.dispose();
  }

  void _startCoachingTimer() {
    _coachTimer?.cancel();
    _coachTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (!_tripState.isActive || _isPaused) return;
      final tip = await _apiService.getCoachingTip(
        idleMinutes: _tripState.idleTimeSeconds ~/ 60,
        speedKmh: _currentSpeedKmh,
        distanceKm: _tripState.cumulativeDistanceM / 1000,
        language: _isHindi ? 'hi' : 'en',
      );
      if (mounted && tip.isNotEmpty) setState(() => _coachingTip = tip);
    });
  }

  void _startTrip() async {
    String? fuelError;
    String? weightError;
    String? engineError;
    if (_selectedFuelType == null) fuelError = s.selectFuelType;
    if (_loadWeightController.text.trim().isEmpty) weightError = s.enterLoadWeight;
    final engineVal = double.tryParse(_engineEffController.text.trim());
    if (engineVal == null || engineVal <= 0) engineError = s.enterEngineEff;
    if (fuelError != null || weightError != null || engineError != null) {
      setState(() { _fuelTypeError = fuelError; _loadWeightError = weightError; _engineEffError = engineError; });
      return;
    }
    final checker = widget.permissionChecker ?? requestLocationPermission;
    final granted = await checker(context);
    if (!granted) return;
    _gpsTracker.startTracking();
    _startCoachingTimer();
    setState(() {
      _fuelTypeError = null; _loadWeightError = null; _engineEffError = null;
      _tripState.isActive = true; _tripState.cumulativeDistanceM = 0.0;
      _tripState.idleTimeSeconds = 0; _tripState.ignitionTimeSeconds = 0;
      _tripState.fuelType = _selectedFuelType;
      _tripState.loadWeightKg = double.tryParse(_loadWeightController.text);
      _tripState.engineEfficiencyKmpl = engineVal;
      _coachingTip = '';
    });
  }

  Future<void> _stopTrip() async {
    _coachTimer?.cancel();
    _gpsTracker.stopTracking();
    final double distanceM = _gpsTracker.cumulativeDistanceM;
    final int idleTimeSeconds = _gpsTracker.idleTimeSeconds;
    final int ignitionTimeSeconds = _gpsTracker.ignitionTimeSeconds;
    final int breakTimeSeconds = _gpsTracker.breakTimeSeconds;
    final String fuelType = _tripState.fuelType ?? 'diesel';
    final double loadWeight = _tripState.loadWeightKg ?? 0.0;
    final double engineEff = _tripState.engineEfficiencyKmpl ?? 10.0;
    setState(() { _isSubmitting = true; });
    try {
      final result = await _apiService.submitTrip(
        distance: distanceM / 1000, fuelType: fuelType,
        idleTime: idleTimeSeconds ~/ 60, loadWeight: loadWeight,
        engineEfficiency: engineEff,
        ignitionTimeMinutes: ignitionTimeSeconds ~/ 60,
        language: _isHindi ? 'hi' : 'en',
      );
      if (!mounted) return;
      setState(() { _tripState.isActive = false; _isSubmitting = false; });
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(
        carbon: result.carbon, distanceM: distanceM,
        idleTimeSeconds: idleTimeSeconds, ignitionTimeSeconds: ignitionTimeSeconds,
        breakTimeSeconds: breakTimeSeconds, insights: result.insights,
        fuelType: fuelType, engineEfficiency: engineEff,
        efficiencyScore: result.efficiencyScore,
        moneySavedEstimate: result.moneySavedEstimate,
        comparisonToAverage: result.comparisonToAverage,
        isHindi: _isHindi,
      )));
      setState(() { _tripState.cumulativeDistanceM = 0.0; _tripState.idleTimeSeconds = 0; _tripState.ignitionTimeSeconds = 0; _coachingTip = ''; });
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _isSubmitting = false; });
      _showSnack(s.timeout);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSubmitting = false; });
      _showSnack('${s.submitError}: $e');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  void _runDemo() {
    if (_isDemoRunning) return;
    setState(() {
      _selectedFuelType = 'diesel'; _loadWeightController.text = '500'; _engineEffController.text = '8';
      _isDemoRunning = true; _demoStep = 0; _demoStatus = s.demoStarting;
      _tripState.isActive = true; _tripState.cumulativeDistanceM = 0.0;
      _tripState.idleTimeSeconds = 0; _tripState.ignitionTimeSeconds = 0;
      _tripState.fuelType = 'diesel'; _tripState.loadWeightKg = 500; _tripState.engineEfficiencyKmpl = 8;
      _isPaused = false; _breakTimeSeconds = 0; _coachingTip = '';
    });
    _demoTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_demoStep >= _demoDistanceSteps.length) { timer.cancel(); _finishDemo(); return; }
      setState(() {
        if (_demoStep == _demoPauseAt) { _gpsTracker.isPaused = true; _gpsTracker.pauseTracking(); _demoStatus = s.demoBreak; }
        else if (_demoStep == _demoResumeAt) { _gpsTracker.resumeTracking(); _demoStatus = s.demoResuming; }
        if (!_gpsTracker.isPaused) {
          final dist = _demoDistanceSteps[_demoStep];
          final isIdle = _demoIdleSteps[_demoStep];
          _tripState.ignitionTimeSeconds += 4;
          _gpsTracker.ignitionTimeSeconds = _tripState.ignitionTimeSeconds;
          if (isIdle) {
            _tripState.idleTimeSeconds += 5; _gpsTracker.idleTimeSeconds = _tripState.idleTimeSeconds;
            _currentSpeedKmh = 0; _demoStatus = s.demoIdle;
          } else if (dist > 0) {
            _tripState.cumulativeDistanceM += dist; _gpsTracker.cumulativeDistanceM = _tripState.cumulativeDistanceM;
            _currentSpeedKmh = 35 + (dist / 100); _demoStatus = s.demoDriving((_tripState.cumulativeDistanceM / 1000).toStringAsFixed(2));
          }
        }
        _breakTimeSeconds = _gpsTracker.breakTimeSeconds + (_gpsTracker.isPaused && _gpsTracker.pausedAt != null ? DateTime.now().difference(_gpsTracker.pausedAt!).inSeconds : 0);
        _isPaused = _gpsTracker.isPaused;
        _demoStep++;
      });
    });
  }

  Future<void> _finishDemo() async {
    setState(() { _demoStatus = s.demoSubmitting; _isSubmitting = true; _tripState.isActive = false; });
    final double distanceM = _tripState.cumulativeDistanceM;
    final int idleTimeSeconds = _tripState.idleTimeSeconds;
    final int ignitionTimeSeconds = _tripState.ignitionTimeSeconds;
    final int breakTimeSeconds = _gpsTracker.breakTimeSeconds;
    try {
      final result = await _apiService.submitTrip(
        distance: distanceM / 1000, fuelType: 'diesel', idleTime: idleTimeSeconds ~/ 60,
        loadWeight: 500, engineEfficiency: 8,
        ignitionTimeMinutes: ignitionTimeSeconds ~/ 60, language: _isHindi ? 'hi' : 'en',
      );
      if (!mounted) return;
      setState(() { _isSubmitting = false; _isDemoRunning = false; _demoStatus = ''; });
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(
        carbon: result.carbon, distanceM: distanceM,
        idleTimeSeconds: idleTimeSeconds, ignitionTimeSeconds: ignitionTimeSeconds,
        breakTimeSeconds: breakTimeSeconds, insights: result.insights,
        fuelType: 'diesel', engineEfficiency: 8,
        efficiencyScore: result.efficiencyScore,
        moneySavedEstimate: result.moneySavedEstimate,
        comparisonToAverage: result.comparisonToAverage,
        isHindi: _isHindi,
      )));
      setState(() { _tripState.cumulativeDistanceM = 0.0; _tripState.idleTimeSeconds = 0; _tripState.ignitionTimeSeconds = 0; _coachingTip = ''; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSubmitting = false; _isDemoRunning = false; _demoStatus = ''; });
      _showSnack('${s.demoError}: $e');
    }
  }

  String get _distanceDisplay => (_tripState.cumulativeDistanceM / 1000).toStringAsFixed(2);
  int get _idleMinutes => _tripState.idleTimeSeconds ~/ 60;
  int get _idleSeconds => _tripState.idleTimeSeconds % 60;
  int get _ignitionMinutes => _tripState.ignitionTimeSeconds ~/ 60;
  int get _ignitionSeconds => _tripState.ignitionTimeSeconds % 60;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _tripState.isActive;
    final bool stopEnabled = isActive && !_isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_shipping, color: Color(0xFF1DB954), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.appName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(s.appSubtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ])),
                // History button
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(isHindi: _isHindi))),
                  icon: Icon(Icons.history, color: Colors.white.withOpacity(0.6)),
                  tooltip: s.tripHistory,
                ),
                // Profile button
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverProfileScreen())),
                  icon: Icon(Icons.person_outline, color: Colors.white.withOpacity(0.6)),
                ),
                // Language toggle
                GestureDetector(
                  onTap: () => setState(() => _isHindi = !_isHindi),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isHindi ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _isHindi ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(_isHindi ? 'हिं' : 'EN', style: TextStyle(color: _isHindi ? const Color(0xFF1DB954) : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Status card
              _StatusCard(isActive: isActive, pulseController: _pulseController, statusText: isActive ? s.statusRunning : s.statusReady),
              const SizedBox(height: 16),

              // Live metrics during trip
              if (isActive) ...[
                // Speedometer + distance row
                Row(children: [
                  Expanded(child: _SpeedometerCard(speedKmh: _currentSpeedKmh, label: s.speed)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(icon: Icons.route, label: s.distance, value: '$_distanceDisplay km', color: const Color(0xFF1DB954))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MetricCard(icon: Icons.timer_outlined, label: s.idleTime, value: '${_idleMinutes}m ${_idleSeconds}s', color: _idleMinutes > 5 ? Colors.orange : const Color(0xFF1DB954))),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(icon: Icons.key, label: s.ignitionTime, value: '${_ignitionMinutes}m ${_ignitionSeconds}s', color: Colors.lightBlue)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MetricCard(icon: Icons.free_breakfast_outlined, label: s.driverBreak, value: '${_breakTimeSeconds ~/ 60}m ${_breakTimeSeconds % 60}s', color: _isPaused ? Colors.amber : Colors.white38)),
                  const SizedBox(width: 12),
                  Expanded(child: _PauseButton(isPaused: _isPaused, breakLabel: s.breakBtn, resumeLabel: s.resumeBtn, onPressed: () {
                    setState(() {
                      if (_isPaused) _gpsTracker.resumeTracking(); else _gpsTracker.pauseTracking();
                      _isPaused = _gpsTracker.isPaused;
                    });
                  })),
                ]),
                // AI coaching tip
                if (_coachingTip.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.psychology, color: Colors.purple, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_coachingTip, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Config section
              _SectionLabel(label: s.tripConfig, enabled: !isActive),
              const SizedBox(height: 12),
              _DarkDropdown(
                value: _selectedFuelType, label: s.fuelType, icon: Icons.local_gas_station,
                enabled: !isActive, errorText: _fuelTypeError,
                items: [DropdownMenuItem(value: 'diesel', child: Text(s.diesel)), DropdownMenuItem(value: 'petrol', child: Text(s.petrol))],
                onChanged: (v) => setState(() { _selectedFuelType = v; _fuelTypeError = null; }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DarkTextField(controller: _loadWeightController, label: s.loadWeight, suffix: 'kg', icon: Icons.scale, enabled: !isActive, errorText: _loadWeightError, onChanged: (_) => setState(() => _loadWeightError = null))),
                const SizedBox(width: 12),
                Expanded(child: _DarkTextField(controller: _engineEffController, label: s.engineEff, suffix: 'km/L', icon: Icons.speed, enabled: !isActive, errorText: _engineEffError, onChanged: (_) => setState(() => _engineEffError = null))),
              ]),
              const SizedBox(height: 28),

              if (!isActive) ...[
                _GreenButton(label: s.startTrip, icon: Icons.play_arrow_rounded, onPressed: _startTrip),
                const SizedBox(height: 12),
                SizedBox(height: 48, child: OutlinedButton.icon(
                  onPressed: _isDemoRunning ? null : _runDemo,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: Text(s.runDemo, style: const TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                )),
              ],

              if (_demoStatus.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                  child: Row(children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_demoStatus, style: const TextStyle(color: Colors.blueAccent, fontSize: 13))),
                  ]),
                ),
              ],

              if (isActive)
                _RedButton(isSubmitting: _isSubmitting, stopLabel: s.stopTrip, calculatingLabel: s.calculating, onPressed: stopEnabled ? _stopTrip : null),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool isActive;
  final AnimationController pulseController;
  final String statusText;
  const _StatusCard({required this.isActive, required this.pulseController, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? Color.lerp(const Color(0xFF1A2E1A), const Color(0xFF1F3A1F), pulseController.value) : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.1), width: isActive ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? const Color(0xFF1DB954) : Colors.grey, boxShadow: isActive ? [BoxShadow(color: const Color(0xFF1DB954).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : null)),
          const SizedBox(width: 12),
          Text(statusText, style: TextStyle(color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Icon(isActive ? Icons.directions_car : Icons.directions_car_outlined, color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

class _SpeedometerCard extends StatelessWidget {
  final double speedKmh;
  final String label;
  const _SpeedometerCard({required this.speedKmh, required this.label});

  Color get _speedColor {
    if (speedKmh < 40) return const Color(0xFF1DB954);
    if (speedKmh < 80) return Colors.orange;
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _speedColor.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.speed, color: _speedColor, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(speedKmh.toStringAsFixed(0), style: TextStyle(color: _speedColor, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('km/h', style: TextStyle(color: _speedColor.withOpacity(0.7), fontSize: 11))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (speedKmh / 120).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(_speedColor),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool enabled;
  const _SectionLabel({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(color: enabled ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }
}

class _DarkDropdown extends StatelessWidget {
  final String? value;
  final String label;
  final IconData icon;
  final bool enabled;
  final String? errorText;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _DarkDropdown({required this.value, required this.label, required this.icon, required this.enabled, required this.items, required this.onChanged, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF1A1F2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: errorText != null ? Colors.red.withOpacity(0.7) : Colors.white.withOpacity(0.1))),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value, isExpanded: true, dropdownColor: const Color(0xFF1A1F2E), style: const TextStyle(color: Colors.white),
          hint: Row(children: [Icon(icon, color: Colors.white.withOpacity(0.4), size: 18), const SizedBox(width: 8), Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4)))]),
          items: items, onChanged: enabled ? onChanged : null,
        )),
      ),
      if (errorText != null) Padding(padding: const EdgeInsets.only(left: 12, top: 4), child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 11))),
    ]);
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  const _DarkTextField({required this.controller, required this.label, required this.suffix, required this.icon, required this.enabled, this.errorText, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, enabled: enabled, style: const TextStyle(color: Colors.white),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        suffixText: suffix, suffixStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
        errorText: errorText, errorStyle: const TextStyle(fontSize: 11),
        filled: true, fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954))),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GreenButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 56, child: ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon, size: 22),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
    ));
  }
}

class _PauseButton extends StatelessWidget {
  final bool isPaused;
  final String breakLabel;
  final String resumeLabel;
  final VoidCallback onPressed;
  const _PauseButton({required this.isPaused, required this.breakLabel, required this.resumeLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 72, child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPaused ? Colors.amber : const Color(0xFF2A2F3E),
        foregroundColor: isPaused ? Colors.black : Colors.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
        side: BorderSide(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24),
        const SizedBox(height: 4),
        Text(isPaused ? resumeLabel : breakLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}

class _RedButton extends StatelessWidget {
  final bool isSubmitting;
  final String stopLabel;
  final String calculatingLabel;
  final VoidCallback? onPressed;
  const _RedButton({required this.isSubmitting, required this.stopLabel, required this.calculatingLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 56, child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
      child: isSubmitting
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 12), Text(calculatingLabel, style: const TextStyle(fontSize: 15))])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.stop_circle_outlined, size: 22), const SizedBox(width: 8), Text(stopLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
    ));
  }
}
