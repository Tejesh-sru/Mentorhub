/// Region of the Cloud Functions (must match functions/src/constants.js).
const String kFunctionsRegion = 'asia-south1';

/// Run against the local Firebase emulators: flutter run --dart-define=USE_EMULATOR=true
const bool kUseEmulator = true;
const String kEmulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1');
