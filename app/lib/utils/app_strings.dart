/// App-wide string constants with English/Hindi support.
class AppStrings {
  final bool isHindi;
  const AppStrings({this.isHindi = false});

  // App
  String get appName => isHindi ? 'कार्बनचेन' : 'CarbonChain';
  String get appSubtitle => isHindi ? 'फ्लीट उत्सर्जन ट्रैकर' : 'Fleet Emissions Tracker';

  // Status
  String get statusRunning => isHindi ? 'यात्रा चल रही है' : 'Trip Running';
  String get statusReady => isHindi ? 'शुरू करने के लिए तैयार' : 'Ready to Start';

  // Config
  String get tripConfig => isHindi ? 'यात्रा कॉन्फ़िगरेशन' : 'Trip Configuration';
  String get fuelType => isHindi ? 'ईंधन प्रकार' : 'Fuel Type';
  String get diesel => isHindi ? 'डीजल' : 'Diesel';
  String get petrol => isHindi ? 'पेट्रोल' : 'Petrol';
  String get loadWeight => isHindi ? 'भार वजन' : 'Load Weight';
  String get engineEff => isHindi ? 'इंजन दक्षता' : 'Engine Eff.';
  String get destDistance => isHindi ? 'गंतव्य दूरी (अनुमानित)' : 'Est. Destination (km)';

  // Metrics
  String get distance => isHindi ? 'दूरी' : 'Distance';
  String get idleTime => isHindi ? 'निष्क्रिय समय' : 'Idle Time';
  String get ignitionTime => isHindi ? 'इग्निशन समय' : 'Ignition Time';
  String get driverBreak => isHindi ? 'ड्राइवर ब्रेक' : 'Driver Break';
  String get speed => isHindi ? 'गति' : 'Speed';
  String get aiCoach => isHindi ? 'AI कोच' : 'AI Coach';

  // Buttons
  String get startTrip => isHindi ? 'यात्रा शुरू करें' : 'Start Trip';
  String get stopTrip => isHindi ? 'यात्रा रोकें' : 'Stop Trip';
  String get runDemo => isHindi ? 'डेमो यात्रा चलाएं' : 'Run Demo Trip';
  String get breakBtn => isHindi ? 'ब्रेक' : 'Break';
  String get resumeBtn => isHindi ? 'फिर शुरू करें' : 'Resume';
  String get calculating => isHindi ? 'उत्सर्जन गणना हो रही है...' : 'Calculating emissions...';
  String get newTrip => isHindi ? 'नई यात्रा' : 'New Trip';

  // Validation
  String get selectFuelType => isHindi ? 'कृपया ईंधन प्रकार चुनें' : 'Please select a fuel type';
  String get enterLoadWeight => isHindi ? 'कृपया भार वजन दर्ज करें' : 'Please enter load weight';
  String get enterEngineEff => isHindi ? 'मान्य दक्षता दर्ज करें (km/L)' : 'Enter valid efficiency (km/L)';

  // Result screen
  String get tripSummary => isHindi ? 'यात्रा सारांश' : 'Trip Summary';
  String get carbonEmissions => isHindi ? 'कार्बन उत्सर्जन' : 'Carbon Emissions';
  String get lowImpact => isHindi ? 'कम प्रभाव' : 'Low Impact';
  String get moderate => isHindi ? 'मध्यम' : 'Moderate';
  String get highImpact => isHindi ? 'उच्च प्रभाव' : 'High Impact';
  String get aiInsights => isHindi ? 'AI अंतर्दृष्टि' : 'AI Insights';
  String get efficiencyScore => isHindi ? 'दक्षता स्कोर' : 'Efficiency Score';
  String get prediction => isHindi ? 'AI भविष्यवाणी' : 'AI Prediction';

  // Errors
  String get timeout => isHindi ? 'अनुरोध समय समाप्त। पुनः प्रयास करें।' : 'Request timed out. Please try again.';
  String get demoError => isHindi ? 'डेमो त्रुटि' : 'Demo error';
  String get submitError => isHindi ? 'यात्रा सबमिट करने में त्रुटि' : 'Error submitting trip';

  // Demo steps
  String get demoStarting => isHindi ? '🚛 डेमो: यात्रा शुरू हो रही है...' : '🚛 Demo: Starting trip...';
  String get demoBreak => isHindi ? '☕ डेमो: ड्राइवर ब्रेक पर...' : '☕ Demo: Driver on break...';
  String get demoResuming => isHindi ? '🚛 डेमो: यात्रा फिर शुरू...' : '🚛 Demo: Resuming trip...';
  String get demoIdle => isHindi ? '⏸ डेमो: वाहन निष्क्रिय...' : '⏸ Demo: Vehicle idling...';
  String get demoSubmitting => isHindi ? '📡 डेमो: बैकएंड को भेज रहे हैं...' : '📡 Demo: Submitting to backend...';
  String demoDriving(String km) => isHindi ? '🚛 डेमो: चल रहा है... $km km' : '🚛 Demo: Driving... $km km';

  // History
  String get tripHistory => isHindi ? 'यात्रा इतिहास' : 'Trip History';
  String get weeklyAnalysis => isHindi ? 'साप्ताहिक AI विश्लेषण' : 'Weekly AI Analysis';
  String get noTrips => isHindi ? 'अभी तक कोई यात्रा नहीं' : 'No trips yet';
  String get loadingHistory => isHindi ? 'इतिहास लोड हो रहा है...' : 'Loading history...';
}
