import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_chain/services/gps_tracker.dart';
import 'package:carbon_chain/services/trip_api_service.dart';
import 'package:carbon_chain/utils/location_permission.dart';
import 'package:carbon_chain/screens/result_screen.dart';

class TripState {
  bool isActive;
  double cumulativeDistanceM;
  int idleTimeSeconds;
  String? fuelType;
  double? loadWeightKg;
  double? engineEfficiencyKmpl;

  TripState({
    this.isActive = false,
    this.cumulativeDistanceM = 0.0,
    this.idleTimeSeconds = 0,
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
  late AnimationController _pulseController;

  final TripState _tripState = TripState();
  String? _selectedFuelType;
  String? _fuelTypeError;
  String? _loadWeightError;
  String? _engineEffError;
  bool _isSubmitting = false;
  bool _isPaused = false;
  int _breakTimeSeconds = 0;
  bool _isDemoRunning = false;
  Timer? _demoTimer;
  int _demoStep = 0;
  String _demoStatus = '';

  // Demo scenario: 12.4 km trip, 8 min idle, 3 min break, diesel, 500kg, 8 km/L
  static const _demoDistanceSteps = [
    800.0, 1200.0, 950.0, 0.0, 0.0, // driving, then idle
    0.0, 0.0,                         // break
    1100.0, 1400.0, 1300.0, 900.0,   // resume driving
    0.0, 0.0, 0.0,                    // idle at destination
    1750.0, 1200.0,                   // final stretch
  ];
  static const _demoIdleSteps = [
    false, false, false, true, true,
    false, false, // break (paused)
    false, false, false, false,
    true, true, true,
    false, false,
  ];
  static const _demoPauseAt = 5;   // step index to pause (break)
  static const _demoResumeAt = 7;  // step index to resume

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tripState.isActive) {
        setState(() {
          _tripState.cumulativeDistanceM = _gpsTracker.cumulativeDistanceM;
          _tripState.idleTimeSeconds = _gpsTracker.idleTimeSeconds;
          _isPaused = _gpsTracker.isPaused;
          _breakTimeSeconds = _gpsTracker.breakTimeSeconds +
              (_gpsTracker.isPaused && _gpsTracker.pausedAt != null
                  ? DateTime.now().difference(_gpsTracker.pausedAt!).inSeconds
                  : 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _demoTimer?.cancel();
    _pulseController.dispose();
    _gpsTracker.stopTracking();
    _loadWeightController.dispose();
    _engineEffController.dispose();
    super.dispose();
  }

  void _startTrip() async {
    String? fuelError;
    String? weightError;
    String? engineError;

    if (_selectedFuelType == null) fuelError = 'Please select a fuel type';
    if (_loadWeightController.text.trim().isEmpty) weightError = 'Please enter load weight';
    final engineVal = double.tryParse(_engineEffController.text.trim());
    if (engineVal == null || engineVal <= 0) engineError = 'Enter valid efficiency (km/L)';

    if (fuelError != null || weightError != null || engineError != null) {
      setState(() {
        _fuelTypeError = fuelError;
        _loadWeightError = weightError;
        _engineEffError = engineError;
      });
      return;
    }

    final checker = widget.permissionChecker ?? requestLocationPermission;
    final granted = await checker(context);
    if (!granted) return;

    _gpsTracker.startTracking();
    setState(() {
      _fuelTypeError = null;
      _loadWeightError = null;
      _engineEffError = null;
      _tripState.isActive = true;
      _tripState.cumulativeDistanceM = 0.0;
      _tripState.idleTimeSeconds = 0;
      _tripState.fuelType = _selectedFuelType;
      _tripState.loadWeightKg = double.tryParse(_loadWeightController.text);
      _tripState.engineEfficiencyKmpl = engineVal;
    });
  }

  Future<void> _stopTrip() async {
    _gpsTracker.stopTracking();

    final double distanceM = _gpsTracker.cumulativeDistanceM;
    final int idleTimeSeconds = _gpsTracker.idleTimeSeconds;
    final int breakTimeSeconds = _gpsTracker.breakTimeSeconds;
    final String fuelType = _tripState.fuelType ?? 'diesel';
    final double loadWeight = _tripState.loadWeightKg ?? 0.0;
    final double engineEff = _tripState.engineEfficiencyKmpl ?? 10.0;

    setState(() { _isSubmitting = true; });

    try {
      final result = await _apiService.submitTrip(
        distance: distanceM / 1000,
        fuelType: fuelType,
        idleTime: idleTimeSeconds ~/ 60,
        loadWeight: loadWeight,
        engineEfficiency: engineEff,
      );

      if (!mounted) return;
      setState(() {
        _tripState.isActive = false;
        _isSubmitting = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            carbon: result.carbon,
            distanceM: distanceM,
            idleTimeSeconds: idleTimeSeconds,
            breakTimeSeconds: breakTimeSeconds,
            insights: result.insights,
            fuelType: fuelType,
            engineEfficiency: engineEff,
          ),
        ),
      );

      setState(() {
        _tripState.cumulativeDistanceM = 0.0;
        _tripState.idleTimeSeconds = 0;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _isSubmitting = false; });
      _showSnack('Request timed out. Please try again.');
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSubmitting = false; });
      _showSnack('Error submitting trip: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _runDemo() {
    if (_isDemoRunning) return;

    // Pre-fill demo values
    setState(() {
      _selectedFuelType = 'diesel';
      _loadWeightController.text = '500';
      _engineEffController.text = '8';
      _isDemoRunning = true;
      _demoStep = 0;
      _demoStatus = 'Demo: Starting trip...';
      _tripState.isActive = true;
      _tripState.cumulativeDistanceM = 0.0;
      _tripState.idleTimeSeconds = 0;
      _tripState.fuelType = 'diesel';
      _tripState.loadWeightKg = 500;
      _tripState.engineEfficiencyKmpl = 8;
      _isPaused = false;
      _breakTimeSeconds = 0;
    });

    _demoTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_demoStep >= _demoDistanceSteps.length) {
        timer.cancel();
        _finishDemo();
        return;
      }

      setState(() {
        // Handle break
        if (_demoStep == _demoPauseAt) {
          _gpsTracker.isPaused = true;
          _gpsTracker.pauseTracking();
          _demoStatus = '☕ Demo: Driver on break...';
        } else if (_demoStep == _demoResumeAt) {
          _gpsTracker.resumeTracking();
          _demoStatus = '🚛 Demo: Resuming trip...';
        }

        if (!_gpsTracker.isPaused) {
          final dist = _demoDistanceSteps[_demoStep];
          final isIdle = _demoIdleSteps[_demoStep];

          if (isIdle) {
            _tripState.idleTimeSeconds += 5;
            _gpsTracker.idleTimeSeconds = _tripState.idleTimeSeconds;
            _demoStatus = '⏸ Demo: Vehicle idling...';
          } else if (dist > 0) {
            _tripState.cumulativeDistanceM += dist;
            _gpsTracker.cumulativeDistanceM = _tripState.cumulativeDistanceM;
            _demoStatus = '🚛 Demo: Driving... ${(_tripState.cumulativeDistanceM / 1000).toStringAsFixed(2)} km';
          }
        }

        _breakTimeSeconds = _gpsTracker.breakTimeSeconds +
            (_gpsTracker.isPaused && _gpsTracker.pausedAt != null
                ? DateTime.now().difference(_gpsTracker.pausedAt!).inSeconds
                : 0);
        _isPaused = _gpsTracker.isPaused;
        _demoStep++;
      });
    });
  }

  Future<void> _finishDemo() async {
    setState(() {
      _demoStatus = '📡 Demo: Submitting to backend...';
      _isSubmitting = true;
      _tripState.isActive = false;
    });

    final double distanceM = _tripState.cumulativeDistanceM;
    final int idleTimeSeconds = _tripState.idleTimeSeconds;
    final int breakTimeSeconds = _gpsTracker.breakTimeSeconds;

    try {
      final result = await _apiService.submitTrip(
        distance: distanceM / 1000,
        fuelType: 'diesel',
        idleTime: idleTimeSeconds ~/ 60,
        loadWeight: 500,
        engineEfficiency: 8,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isDemoRunning = false;
        _demoStatus = '';
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            carbon: result.carbon,
            distanceM: distanceM,
            idleTimeSeconds: idleTimeSeconds,
            breakTimeSeconds: breakTimeSeconds,
            insights: result.insights,
            fuelType: 'diesel',
            engineEfficiency: 8,
          ),
        ),
      );

      setState(() {
        _tripState.cumulativeDistanceM = 0.0;
        _tripState.idleTimeSeconds = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSubmitting = false; _isDemoRunning = false; _demoStatus = ''; });
      _showSnack('Demo error: $e');
    }
  }

  String get _distanceDisplay => (_tripState.cumulativeDistanceM / 1000).toStringAsFixed(2);
  int get _idleMinutes => _tripState.idleTimeSeconds ~/ 60;
  int get _idleSeconds => _tripState.idleTimeSeconds % 60;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _tripState.isActive;
    final bool stopEnabled = isActive && !_isSubmitting;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping, color: Color(0xFF1DB954), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CarbonChain', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Fleet Emissions Tracker', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status card
              _StatusCard(isActive: isActive, pulseController: _pulseController),
              const SizedBox(height: 20),

              // Live metrics (shown during trip)
              if (isActive) ...[
                Row(
                  children: [
                    Expanded(child: _MetricCard(icon: Icons.route, label: 'Distance', value: '$_distanceDisplay km', color: const Color(0xFF1DB954))),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricCard(
                      icon: Icons.timer_outlined,
                      label: 'Idle Time',
                      value: '${_idleMinutes}m ${_idleSeconds}s',
                      color: _idleMinutes > 5 ? Colors.orange : const Color(0xFF1DB954),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // Break time + pause button
                Row(
                  children: [
                    Expanded(child: _MetricCard(
                      icon: Icons.free_breakfast_outlined,
                      label: 'Break Time',
                      value: '${_breakTimeSeconds ~/ 60}m ${_breakTimeSeconds % 60}s',
                      color: _isPaused ? Colors.amber : Colors.white38,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PauseButton(
                        isPaused: _isPaused,
                        onPressed: () {
                          setState(() {
                            if (_isPaused) {
                              _gpsTracker.resumeTracking();
                            } else {
                              _gpsTracker.pauseTracking();
                            }
                            _isPaused = _gpsTracker.isPaused;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              // Input fields
              _SectionLabel(label: 'Trip Configuration', enabled: !isActive),
              const SizedBox(height: 12),

              // Fuel type
              _DarkDropdown(
                value: _selectedFuelType,
                label: 'Fuel Type',
                icon: Icons.local_gas_station,
                enabled: !isActive,
                errorText: _fuelTypeError,
                items: const [
                  DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                  DropdownMenuItem(value: 'petrol', child: Text('Petrol')),
                ],
                onChanged: (v) => setState(() { _selectedFuelType = v; _fuelTypeError = null; }),
              ),
              const SizedBox(height: 12),

              // Load weight + engine efficiency side by side
              Row(
                children: [
                  Expanded(
                    child: _DarkTextField(
                      controller: _loadWeightController,
                      label: 'Load Weight',
                      suffix: 'kg',
                      icon: Icons.scale,
                      enabled: !isActive,
                      errorText: _loadWeightError,
                      onChanged: (_) => setState(() { _loadWeightError = null; }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DarkTextField(
                      controller: _engineEffController,
                      label: 'Engine Eff.',
                      suffix: 'km/L',
                      icon: Icons.speed,
                      enabled: !isActive,
                      errorText: _engineEffError,
                      onChanged: (_) => setState(() { _engineEffError = null; }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Start button
              if (!isActive)
                _GreenButton(
                  label: 'Start Trip',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _startTrip,
                ),

              // Demo button (only when not active)
              if (!isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isDemoRunning ? null : _runDemo,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Run Demo Trip', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              // Demo status label
              if (_demoStatus.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_demoStatus, style: const TextStyle(color: Colors.blueAccent, fontSize: 13))),
                    ],
                  ),
                ),
              ],

              // Stop button
              if (isActive)
                _RedButton(
                  isSubmitting: _isSubmitting,
                  onPressed: stopEnabled ? _stopTrip : null,
                ),
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

  const _StatusCard({required this.isActive, required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Color.lerp(const Color(0xFF1A2E1A), const Color(0xFF1F3A1F), pulseController.value)
              : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.1),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF1DB954) : Colors.grey,
                boxShadow: isActive ? [BoxShadow(color: const Color(0xFF1DB954).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isActive ? 'Trip Running' : 'Ready to Start',
              style: TextStyle(
                color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(
              isActive ? Icons.directions_car : Icons.directions_car_outlined,
              color: isActive ? const Color(0xFF1DB954) : Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool enabled;

  const _SectionLabel({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: enabled ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.3),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
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

  const _DarkDropdown({
    required this.value, required this.label, required this.icon,
    required this.enabled, required this.items, required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? Colors.red.withOpacity(0.7) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1F2E),
              style: const TextStyle(color: Colors.white),
              hint: Row(children: [
                Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4))),
              ]),
              items: items,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
      ],
    );
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

  const _DarkTextField({
    required this.controller, required this.label, required this.suffix,
    required this.icon, required this.enabled, this.errorText, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        suffixText: suffix,
        suffixStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1DB954)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
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
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPressed;

  const _PauseButton({required this.isPaused, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPaused ? Colors.amber : const Color(0xFF2A2F3E),
          foregroundColor: isPaused ? Colors.black : Colors.amber,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          side: BorderSide(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24),
            const SizedBox(height: 4),
            Text(
              isPaused ? 'Resume' : 'Break',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedButton extends StatelessWidget {  final bool isSubmitting;
  final VoidCallback? onPressed;

  const _RedButton({required this.isSubmitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('Calculating emissions...', style: TextStyle(fontSize: 15)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_circle_outlined, size: 22),
                  SizedBox(width: 8),
                  Text('Stop Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}
