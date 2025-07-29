import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

void main() {
  runApp(const GuitarTunerApp());
}

class GuitarTunerApp extends StatelessWidget {
  const GuitarTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitar Tuner Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: const TunerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with TickerProviderStateMixin {
  // Audio processing variables
  bool _isListening = false;
  double _currentFrequency = 0.0;
  String _currentNote = 'A';
  int _currentOctave = 4;
  double _centsOffset = 0.0;
  double _confidence = 0.0;
  bool _isInTune = false;

  // Real-time audio processing
  FlutterSoundRecorder? _audioRecorder;
  StreamSubscription? _audioSubscription;
  final List<double> _audioBuffer = [];
  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096;

  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>();
  Timer? _processingTimer;

  // Enhanced tuning parameters
  double _tuningReference = 440.0;
  double _centsTolerance = 10.0;
  bool _useAdvancedFiltering = true;
  String _selectedTuning = 'Standard';

  // Frequency range feedback
  String _frequencyFeedback = '';
  bool _showFrequencyWarning = false;

  // Performance monitoring
  int _processingLatency = 0;
  double _signalLevel = 0.0;

  // UI Animation controllers
  late AnimationController _pulseController;
  late AnimationController _needleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _needleAnimation;

  // Guitar tuning presets
  final Map<String, Map<String, double>> _tuningPresets = {
    'Standard': {
      'E2': 82.41, 'A2': 110.00, 'D3': 146.83,
      'G3': 196.00, 'B3': 246.94, 'E4': 329.63,
    },
    'Drop D': {
      'D2': 73.42, 'A2': 110.00, 'D3': 146.83,
      'G3': 196.00, 'B3': 246.94, 'E4': 329.63,
    },
    'Open G': {
      'D2': 73.42, 'G2': 98.00, 'D3': 146.83,
      'G3': 196.00, 'B3': 246.94, 'D4': 293.66,
    },
    'DADGAD': {
      'D2': 73.42, 'A2': 110.00, 'D3': 146.83,
      'G3': 196.00, 'A3': 220.00, 'D4': 293.66,
    },
  };

  // Enhanced musical note frequencies lookup table
  static const Map<String, double> _allNoteFrequencies = {
    // Octave 0
    'C0': 16.35, 'C#0': 17.32, 'D0': 18.35, 'D#0': 19.45, 'E0': 20.60, 'F0': 21.83,
    'F#0': 23.12, 'G0': 24.50, 'G#0': 25.96, 'A0': 27.50, 'A#0': 29.14, 'B0': 30.87,

    // Octave 1
    'C1': 32.70, 'C#1': 34.65, 'D1': 36.71, 'D#1': 38.89, 'E1': 41.20, 'F1': 43.65,
    'F#1': 46.25, 'G1': 49.00, 'G#1': 51.91, 'A1': 55.00, 'A#1': 58.27, 'B1': 61.74,

    // Octave 2
    'C2': 65.41, 'C#2': 69.30, 'D2': 73.42, 'D#2': 77.78, 'E2': 82.41, 'F2': 87.31,
    'F#2': 92.50, 'G2': 98.00, 'G#2': 103.8, 'A2': 110.0, 'A#2': 116.5, 'B2': 123.5,

    // Octave 3
    'C3': 130.8, 'C#3': 138.6, 'D3': 146.8, 'D#3': 155.6, 'E3': 164.8, 'F3': 174.6,
    'F#3': 185.0, 'G3': 196.0, 'G#3': 207.7, 'A3': 220.0, 'A#3': 233.1, 'B3': 246.9,

    // Octave 4
    'C4': 261.6, 'C#4': 277.2, 'D4': 293.7, 'D#4': 311.1, 'E4': 329.6, 'F4': 349.2,
    'F#4': 370.0, 'G4': 392.0, 'G#4': 415.3, 'A4': 440.0, 'A#4': 466.2, 'B4': 493.9,

    // Octave 5
    'C5': 523.3, 'C#5': 554.4, 'D5': 587.3, 'D#5': 622.3, 'E5': 659.3, 'F5': 698.5,
    'F#5': 740.0, 'G5': 784.0, 'G#5': 830.6, 'A5': 880.0, 'A#5': 932.3, 'B5': 987.8,

    // Octave 6
    'C6': 1047, 'C#6': 1109, 'D6': 1175, 'D#6': 1245, 'E6': 1319, 'F6': 1397,
    'F#6': 1480, 'G6': 1568, 'G#6': 1661, 'A6': 1760, 'A#6': 1865, 'B6': 1976,
  };

  // Musical ranges
  static const double _minimumMusicalFreq = 27.50;  // A0
  static const double _maximumMusicalFreq = 4186.0; // C8
  static const double _guitarRangeMin = 70.0;       // Around D2
  static const double _guitarRangeMax = 1500.0;     // High guitar harmonics

  final RealTimePitchDetector _pitchDetector = RealTimePitchDetector();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
    _loadUserSettings();
    _requestPermissions();

    _audioSubscription = _audioStreamController.stream.listen((data) {
      _processAudioData(data);
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _needleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _needleAnimation = Tween<double>(begin: -50.0, end: 50.0)
        .animate(CurvedAnimation(parent: _needleController, curve: Curves.elasticOut));
  }

  Future<void> _initializeAudio() async {
    _audioRecorder = FlutterSoundRecorder();
    try {
      await _audioRecorder!.openRecorder();
      await _audioRecorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
    } catch (e) {
      print('Error initializing audio recorder: $e');
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _tuningReference = prefs.getDouble('tuning_reference') ?? 440.0;
        _centsTolerance = prefs.getDouble('cents_tolerance') ?? 10.0;
        _useAdvancedFiltering = prefs.getBool('advanced_filtering') ?? true;
        _selectedTuning = prefs.getString('selected_tuning') ?? 'Standard';
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tuning_reference', _tuningReference);
      await prefs.setDouble('cents_tolerance', _centsTolerance);
      await prefs.setBool('advanced_filtering', _useAdvancedFiltering);
      await prefs.setString('selected_tuning', _selectedTuning);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text('This app needs microphone access to detect pitch and tune your guitar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startListening() async {
    if (_audioRecorder == null) {
      await _initializeAudio();
    }

    try {
      setState(() {
        _isListening = true;
      });

      await WakelockPlus.enable();

      await _audioRecorder!.startRecorder(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _sampleRate,
        toStream: _audioStreamController.sink,
      );

      _pulseController.repeat(reverse: true);
    } catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isListening = false;
        _resetDisplay();
      });
      await WakelockPlus.disable();
    }
  }

  Future<void> _stopListening() async {
    try {
      setState(() {
        _isListening = false;
        _resetDisplay();
      });

      await _audioRecorder?.stopRecorder();
      _processingTimer?.cancel();
      _audioBuffer.clear();
      _pulseController.stop();
      await WakelockPlus.disable();
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _resetDisplay() {
    _currentFrequency = 0.0;
    _currentNote = 'A';
    _currentOctave = 4;
    _centsOffset = 0.0;
    _confidence = 0.0;
    _isInTune = false;
    _frequencyFeedback = '';
    _showFrequencyWarning = false;
    _signalLevel = 0.0;
  }

  void _processAudioData(Uint8List rawData) {
    final startTime = DateTime.now();

    final samples = <double>[];
    double signalSum = 0.0;
    double maxAmplitude = 0.0;

    for (int i = 0; i < rawData.length - 1; i += 2) {
      final sample = (rawData[i] | (rawData[i + 1] << 8));
      final normalizedSample = sample.toDouble() / 32768.0;
      samples.add(normalizedSample);

      final amplitude = normalizedSample.abs();
      signalSum += amplitude;
      if (amplitude > maxAmplitude) {
        maxAmplitude = amplitude;
      }
    }

    _signalLevel = samples.isNotEmpty ? signalSum / samples.length : 0.0;
    final rmsLevel = sqrt(samples.map((s) => s * s).reduce((a, b) => a + b) / samples.length);

    const double noiseThreshold = 0.01;
    const double musicThreshold = 0.05;
    const double confidenceThreshold = 0.5;

    if (rmsLevel < noiseThreshold || maxAmplitude < musicThreshold) {
      if (mounted) {
        setState(() {
          _resetDisplay();
        });
      }
      return;
    }

    _audioBuffer.addAll(samples);

    if (_audioBuffer.length >= _bufferSize) {
      final bufferToProcess = _audioBuffer.take(_bufferSize).toList();
      _audioBuffer.removeRange(0, _bufferSize ~/ 2);

      Map<String, dynamic> result;
      if (_useAdvancedFiltering) {
        result = _pitchDetector.detectPitchWithFiltering(
          bufferToProcess,
          _sampleRate.toDouble(),
          _tuningReference,
          rmsLevel,
        );
      } else {
        result = _pitchDetector.detectPitch(bufferToProcess, _sampleRate.toDouble());
      }

      final endTime = DateTime.now();
      _processingLatency = endTime.difference(startTime).inMilliseconds;

      if (mounted && result['confidence'] > confidenceThreshold && result['frequency'] > 0) {
        final frequency = result['frequency'];

        String feedback = '';
        bool showWarning = false;
        bool isValidForDisplay = false;

        if (frequency < _minimumMusicalFreq) {
          feedback = 'Frequency too low (${frequency.toStringAsFixed(1)} Hz)';
          showWarning = true;
        } else if (frequency > _maximumMusicalFreq) {
          feedback = 'Frequency too high (${frequency.toStringAsFixed(1)} Hz)';
          showWarning = true;
        } else if (frequency < _guitarRangeMin) {
          feedback = 'Below guitar range (${frequency.toStringAsFixed(1)} Hz)';
          showWarning = true;
          isValidForDisplay = true;
        } else if (frequency > _guitarRangeMax) {
          feedback = 'Above typical guitar range (${frequency.toStringAsFixed(1)} Hz)';
          showWarning = true;
          isValidForDisplay = true;
        } else {
          isValidForDisplay = true;
          feedback = '';
          showWarning = false;
        }

        setState(() {
          _frequencyFeedback = feedback;
          _showFrequencyWarning = showWarning;

          if (isValidForDisplay) {
            _currentFrequency = frequency;
            _currentNote = result['note'];
            _currentOctave = result['octave'];
            _centsOffset = result['cents'];
            _confidence = result['confidence'];
            _isInTune = _centsOffset.abs() < _centsTolerance;

            final clampedOffset = _centsOffset.clamp(-50.0, 50.0);
            _needleController.animateTo(clampedOffset / 50.0);

            if (_confidence > 0.8 && !showWarning) {
              if (_isInTune) {
                HapticFeedback.lightImpact();
              } else if (_centsOffset.abs() < _centsTolerance * 2) {
                HapticFeedback.selectionClick();
              }
            }
          } else {
            _currentFrequency = frequency;
            _currentNote = 'A';
            _currentOctave = 4;
            _centsOffset = 0.0;
            _confidence = 0.0;
            _isInTune = false;
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _resetDisplay();
          });
        }
      }
    }
  }

  Color _getTuningColor() {
    if (!_isListening) return Colors.grey;
    if (_isInTune) return Colors.green;
    if (_centsOffset.abs() < _centsTolerance * 2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Guitar Tuner Pro',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Frequency and Note Display
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getTuningColor(),
                            boxShadow: [
                              BoxShadow(
                                color: _getTuningColor().withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$_currentNote$_currentOctave',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  Text(
                    '${_currentFrequency.toStringAsFixed(2)} Hz',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  if (_showFrequencyWarning) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _frequencyFeedback,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_isListening) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.signal_cellular_4_bar, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.grey[700],
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (_signalLevel * 5).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _signalLevel > 0.1 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Latency: ${_processingLatency}ms',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Tuning Meter
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    '${_centsOffset > 0 ? '+' : ''}${_centsOffset.toStringAsFixed(0)} cents',
                    style: TextStyle(
                      fontSize: 18,
                      color: _getTuningColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomPaint(
                    size: const Size(300, 80),
                    painter: TuningMeterPainter(
                      centsOffset: _centsOffset,
                      isListening: _isListening,
                      tuningColor: _getTuningColor(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Guitar Strings Reference
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_selectedTuning Tuning',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showTuningSelector,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Change', style: TextStyle(color: Colors.blue, fontSize: 12)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, color: Colors.blue, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _tuningPresets[_selectedTuning]!.entries.map((entry) {
                      final isActive = _isStringActive(entry.key, entry.value);
                      return _buildStringButton(entry.key, entry.value, isActive);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Control Buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showFeatureDialog('Auto-tune'),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red : Colors.green,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : Colors.green).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleAdvancedMode,
                  icon: Icon(_useAdvancedFiltering ? Icons.tune : Icons.music_note),
                  label: Text(_useAdvancedFiltering ? 'Advanced' : 'Basic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _useAdvancedFiltering ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isStringActive(String stringName, double targetFreq) {
    if (!_isListening || _currentFrequency == 0) return false;
    final ratio = _currentFrequency / targetFreq;
    final semitones = 12 * log(ratio) / log(2);
    return semitones.abs() < 1.0;
  }

  void _showTuningSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d2d2d),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Tuning',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            ..._tuningPresets.keys.map((tuning) => ListTile(
              title: Text(tuning, style: const TextStyle(color: Colors.white)),
              subtitle: Text(_getTuningDescription(tuning),
                  style: const TextStyle(color: Colors.white70)),
              trailing: _selectedTuning == tuning
                  ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                setState(() {
                  _selectedTuning = tuning;
                });
                _saveUserSettings();
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  String _getTuningDescription(String tuning) {
    switch (tuning) {
      case 'Standard': return 'E-A-D-G-B-E (Classic guitar tuning)';
      case 'Drop D': return 'D-A-D-G-B-E (Heavy rock/metal)';
      case 'Open G': return 'D-G-D-G-B-D (Slide guitar, blues)';
      case 'DADGAD': return 'D-A-D-G-A-D (Celtic, acoustic)';
      default: return '';
    }
  }

  void _toggleAdvancedMode() {
    setState(() {
      _useAdvancedFiltering = !_useAdvancedFiltering;
    });
    _saveUserSettings();
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_useAdvancedFiltering
            ? 'Advanced filtering enabled - better accuracy'
            : 'Basic mode - faster response'),
        duration: const Duration(seconds: 2),
        backgroundColor: _useAdvancedFiltering ? Colors.green : Colors.blue,
      ),
    );
  }

  Widget _buildStringButton(String note, double frequency, bool isActive) {
    return GestureDetector(
      onTap: () => _playReferenceNote(frequency),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.blue : Colors.grey[700],
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey[600]!,
            width: 2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            note.substring(0, note.length - 1),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[300],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _playReferenceNote(double frequency) {
    HapticFeedback.selectionClick();
    if (_currentFrequency > 0) {
      final cents = 1200 * log(_currentFrequency / frequency) / log(2);
      final centsText = cents > 0 ? '+${cents.toStringAsFixed(0)}' : cents.toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                cents.abs() < 10 ? Icons.check_circle : Icons.info,
                color: cents.abs() < 10 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text('Target: ${frequency.toStringAsFixed(2)} Hz | Difference: $centsText cents'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: cents.abs() < 10 ? Colors.green : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target note: ${frequency.toStringAsFixed(2)} Hz'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Tuner Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.white),
              title: const Text('Tuning Tolerance', style: TextStyle(color: Colors.white)),
              subtitle: Text('±${_centsTolerance.toInt()} cents',
                  style: const TextStyle(color: Colors.white70)),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: _centsTolerance,
                  min: 5.0,
                  max: 25.0,
                  divisions: 4,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _centsTolerance = value;
                    });
                  },
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.white),
              title: const Text('Reference Pitch', style: TextStyle(color: Colors.white)),
              subtitle: Text('A4 = ${_tuningReference.toInt()} Hz',
                  style: const TextStyle(color: Colors.white70)),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: _tuningReference,
                  min: 435.0,
                  max: 445.0,
                  divisions: 10,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _tuningReference = value;
                    });
                  },
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Advanced Filtering', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Better accuracy, slightly slower',
                  style: TextStyle(color: Colors.white70)),
              value: _useAdvancedFiltering,
              activeColor: Colors.blue,
              onChanged: (value) {
                setState(() {
                  _useAdvancedFiltering = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveUserSettings();
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(feature, style: const TextStyle(color: Colors.white)),
        content: Text('$feature feature would be implemented here with additional audio processing capabilities.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _needleController.dispose();
    _stopListening();
    _audioRecorder?.closeRecorder();
    _audioStreamController.close();
    _processingTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}

// Custom painter for the tuning meter
class TuningMeterPainter extends CustomPainter {
  final double centsOffset;
  final bool isListening;
  final Color tuningColor;

  TuningMeterPainter({
    required this.centsOffset,
    required this.isListening,
    required this.tuningColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw meter background
    paint.color = Colors.grey[600]!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size.width, height: 40),
        const Radius.circular(20),
      ),
      paint,
    );

    // Draw scale marks
    paint.strokeWidth = 1;
    for (int i = -50; i <= 50; i += 10) {
      final x = center.dx + (i / 50) * (size.width / 2 - 20);
      final y1 = center.dy - 15;
      final y2 = center.dy + 15;

      paint.color = i == 0 ? Colors.white : Colors.grey[400]!;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }

    // Draw needle
    if (isListening) {
      final needleX = center.dx + (centsOffset / 50) * (size.width / 2 - 20);
      paint.color = tuningColor;
      paint.strokeWidth = 4;
      paint.strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(needleX, center.dy - 20),
        Offset(needleX, center.dy + 20),
        paint,
      );

      // Draw needle tip
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(needleX, center.dy), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Real-time pitch detection class
class RealTimePitchDetector {
  static const double _noiseGate = 0.01;
  static const double _maxFrequency = 2000.0;
  static const double _minFrequency = 50.0;

  Map<String, dynamic> detectPitchWithFiltering(
      List<double> audioSamples,
      double sampleRate,
      double referenceFreq,
      double signalStrength,
      ) {
    final dynamicNoiseGate = _noiseGate + (0.02 * (1.0 - signalStrength));

    final filtered = _applyPreFiltering(audioSamples);
    final signalLevel = _calculateRMS(filtered);

    if (signalLevel < dynamicNoiseGate) {
      return _getDefaultResult();
    }

    final denoised = _spectralSubtraction(filtered, signalLevel);
    final yinResult = _yinPitchDetection(denoised, sampleRate);
    final autocorrResult = _autocorrelationDetection(denoised, sampleRate);

    if (yinResult['confidence'] > 0.6 && autocorrResult['confidence'] > 0.4) {
      final freqDiff = (yinResult['frequency'] - autocorrResult['frequency']).abs();
      final avgFreq = (yinResult['frequency'] + autocorrResult['frequency']) / 2;

      if (freqDiff < avgFreq * 0.05) {
        final combinedResult = _combineResults(yinResult, autocorrResult);
        if (_isValidMusicalFrequency(combinedResult['frequency'])) {
          final noteData = _frequencyToNote(combinedResult['frequency'], referenceFreq);
          final adjustedConfidence = combinedResult['confidence'] * (0.8 + 0.2 * signalStrength);

          return {
            'frequency': combinedResult['frequency'],
            'note': noteData['note'],
            'octave': noteData['octave'],
            'cents': noteData['cents'],
            'confidence': adjustedConfidence.clamp(0.0, 1.0),
          };
        }
      }
    }

    final bestResult = yinResult['confidence'] > autocorrResult['confidence']
        ? yinResult : autocorrResult;

    if (bestResult['confidence'] > 0.4 && _isValidMusicalFrequency(bestResult['frequency'])) {
      final noteData = _frequencyToNote(bestResult['frequency'], referenceFreq);
      final adjustedConfidence = bestResult['confidence'] * (0.8 + 0.2 * signalStrength);

      return {
        'frequency': bestResult['frequency'],
        'note': noteData['note'],
        'octave': noteData['octave'],
        'cents': noteData['cents'],
        'confidence': adjustedConfidence.clamp(0.0, 1.0),
      };
    }

    return _getDefaultResult();
  }

  Map<String, dynamic> detectPitch(List<double> audioSamples, double sampleRate) {
    if (audioSamples.length < 1024) {
      return _getDefaultResult();
    }

    try {
      final yinResult = _yinPitchDetection(audioSamples, sampleRate);

      if (yinResult['frequency'] > 0 && yinResult['confidence'] > 0.3) {
        final noteData = _frequencyToNote(yinResult['frequency'], 440.0);
        return {
          'frequency': yinResult['frequency'],
          'note': noteData['note'],
          'octave': noteData['octave'],
          'cents': noteData['cents'],
          'confidence': yinResult['confidence'],
        };
      }
    } catch (e) {
      print('Pitch detection error: $e');
    }

    return _getDefaultResult();
  }

  List<double> _applyPreFiltering(List<double> samples) {
    final highPassed = _highPassFilter(samples, 0.95);
    final bandPassed = _bandPassFilter(highPassed, 70.0, 400.0, 44100.0);
    return _smoothingFilter(bandPassed);
  }

  List<double> _highPassFilter(List<double> samples, double alpha) {
    final filtered = <double>[];
    double prevInput = 0.0;
    double prevOutput = 0.0;

    for (final sample in samples) {
      final output = alpha * (prevOutput + sample - prevInput);
      filtered.add(output);
      prevInput = sample;
      prevOutput = output;
    }

    return filtered;
  }

  List<double> _bandPassFilter(List<double> samples, double lowFreq, double highFreq, double sampleRate) {
    final filtered = <double>[];
    double x1 = 0.0, x2 = 0.0;
    double y1 = 0.0, y2 = 0.0;

    for (final sample in samples) {
      final output = 0.1 * (sample - x2) + 0.8 * y1 - 0.3 * y2;
      filtered.add(output);

      x2 = x1;
      x1 = sample;
      y2 = y1;
      y1 = output;
    }

    return filtered;
  }

  List<double> _smoothingFilter(List<double> samples) {
    if (samples.length < 3) return samples;

    final smoothed = <double>[];
    smoothed.add(samples[0]);

    for (int i = 1; i < samples.length - 1; i++) {
      final avg = (samples[i - 1] + samples[i] + samples[i + 1]) / 3.0;
      smoothed.add(avg);
    }

    smoothed.add(samples.last);
    return smoothed;
  }

  List<double> _spectralSubtraction(List<double> samples, double signalLevel) {
    final threshold = signalLevel * 0.1;

    return samples.map((sample) {
      final magnitude = sample.abs();
      if (magnitude < threshold) {
        return sample * 0.1;
      }
      return sample;
    }).toList();
  }

  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return sqrt(sum / samples.length);
  }

  bool _isValidMusicalFrequency(double frequency) {
    return frequency >= _minFrequency && frequency <= _maxFrequency;
  }

  Map<String, dynamic> _combineResults(Map<String, dynamic> result1, Map<String, dynamic> result2) {
    final avgFreq = (result1['frequency'] + result2['frequency']) / 2;
    final avgConfidence = (result1['confidence'] + result2['confidence']) / 2;

    return {
      'frequency': avgFreq,
      'confidence': avgConfidence * 1.1,
    };
  }

  Map<String, dynamic> _autocorrelationDetection(List<double> samples, double sampleRate) {
    final windowed = _applyHanningWindow(samples);
    final autocorr = _autocorrelation(windowed);
    return _findFundamentalFrequency(autocorr, sampleRate);
  }

  Map<String, dynamic> _getDefaultResult() {
    return {
      'frequency': 0.0,
      'note': 'A',
      'octave': 4,
      'cents': 0.0,
      'confidence': 0.0,
    };
  }

  Map<String, dynamic> _yinPitchDetection(List<double> samples, double sampleRate) {
    final int windowSize = samples.length;
    final int halfWindow = windowSize ~/ 2;

    final List<double> difference = List.filled(halfWindow, 0.0);
    for (int tau = 1; tau < halfWindow; tau++) {
      double sum = 0.0;
      for (int i = 0; i < halfWindow; i++) {
        final delta = samples[i] - samples[i + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    final List<double> cmndf = List.filled(halfWindow, 1.0);
    double runningSum = 0.0;

    for (int tau = 1; tau < halfWindow; tau++) {
      runningSum += difference[tau];
      if (runningSum != 0) {
        cmndf[tau] = difference[tau] * tau / runningSum;
      }
    }

    const double threshold = 0.15;
    final List<int> candidates = [];

    for (int tau = 2; tau < halfWindow; tau++) {
      if (cmndf[tau] < threshold) {
        int localMin = tau;
        while (localMin + 1 < halfWindow && cmndf[localMin + 1] < cmndf[localMin]) {
          localMin++;
        }

        if (localMin > 0 && localMin < halfWindow - 1) {
          final prominence = (cmndf[localMin - 1] + cmndf[localMin + 1]) / 2 - cmndf[localMin];
          if (prominence > 0.05) {
            candidates.add(localMin);
          }
        }

        tau = localMin;
      }
    }

    if (candidates.isEmpty) {
      return {'frequency': 0.0, 'confidence': 0.0};
    }

    int bestTau = candidates[0];
    double bestValue = cmndf[bestTau];

    for (final candidate in candidates) {
      if (cmndf[candidate] < bestValue) {
        bestValue = cmndf[candidate];
        bestTau = candidate;
      }
    }

    double betterTau = bestTau.toDouble();
    if (bestTau > 0 && bestTau < cmndf.length - 1) {
      final double s0 = cmndf[bestTau - 1];
      final double s1 = cmndf[bestTau];
      final double s2 = cmndf[bestTau + 1];

      final denominator = 2 * (2 * s1 - s2 - s0);
      if (denominator.abs() > 1e-10) {
        betterTau = bestTau + (s2 - s0) / denominator;
      }
    }

    final double frequency = sampleRate / betterTau;
    double confidence = 1.0 - bestValue;

    if (frequency >= 80 && frequency <= 1000) {
      confidence *= 1.2;
    }

    if (frequency < _minFrequency || frequency > _maxFrequency) {
      confidence *= 0.5;
    }

    confidence = confidence.clamp(0.0, 1.0);

    return {
      'frequency': frequency,
      'confidence': confidence,
    };
  }

  Map<String, dynamic> _frequencyToNote(double frequency, double referenceFreq) {
    if (frequency <= 0) {
      return {'note': 'A', 'octave': 4, 'cents': 0.0};
    }

    // Enhanced frequency to note conversion using lookup table
    const Map<String, double> noteFreqs = {
      'C0': 16.35, 'C#0': 17.32, 'D0': 18.35, 'D#0': 19.45, 'E0': 20.60, 'F0': 21.83,
      'F#0': 23.12, 'G0': 24.50, 'G#0': 25.96, 'A0': 27.50, 'A#0': 29.14, 'B0': 30.87,
      'C1': 32.70, 'C#1': 34.65, 'D1': 36.71, 'D#1': 38.89, 'E1': 41.20, 'F1': 43.65,
      'F#1': 46.25, 'G1': 49.00, 'G#1': 51.91, 'A1': 55.00, 'A#1': 58.27, 'B1': 61.74,
      'C2': 65.41, 'C#2': 69.30, 'D2': 73.42, 'D#2': 77.78, 'E2': 82.41, 'F2': 87.31,
      'F#2': 92.50, 'G2': 98.00, 'G#2': 103.8, 'A2': 110.0, 'A#2': 116.5, 'B2': 123.5,
      'C3': 130.8, 'C#3': 138.6, 'D3': 146.8, 'D#3': 155.6, 'E3': 164.8, 'F3': 174.6,
      'F#3': 185.0, 'G3': 196.0, 'G#3': 207.7, 'A3': 220.0, 'A#3': 233.1, 'B3': 246.9,
      'C4': 261.6, 'C#4': 277.2, 'D4': 293.7, 'D#4': 311.1, 'E4': 329.6, 'F4': 349.2,
      'F#4': 370.0, 'G4': 392.0, 'G#4': 415.3, 'A4': 440.0, 'A#4': 466.2, 'B4': 493.9,
      'C5': 523.3, 'C#5': 554.4, 'D5': 587.3, 'D#5': 622.3, 'E5': 659.3, 'F5': 698.5,
      'F#5': 740.0, 'G5': 784.0, 'G#5': 830.6, 'A5': 880.0, 'A#5': 932.3, 'B5': 987.8,
      'C6': 1047, 'C#6': 1109, 'D6': 1175, 'D#6': 1245, 'E6': 1319, 'F6': 1397,
    };

    String closestNoteName = 'A4';
    double closestFreq = 440.0;
    double minDifference = double.infinity;

    noteFreqs.forEach((noteName, noteFreq) {
      final difference = (frequency - noteFreq).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestNoteName = noteName;
        closestFreq = noteFreq;
      }
    });

    final cents = 1200 * log(frequency / closestFreq) / log(2);

    final RegExp noteRegex = RegExp(r'^([A-G]#?)(\d+)$');
        final match = noteRegex.firstMatch(closestNoteName);

    if (match != null) {
      final noteName = match.group(1)!;
      final octave = int.parse(match.group(2)!);

      return {
        'note': noteName,
        'octave': octave,
        'cents': cents,
      };
    }

    // Fallback
    const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final double midiNote = 12 * (log(frequency / 440.0) / log(2)) + 69;
    final int roundedMidi = midiNote.round();
    final double fallbackCents = (midiNote - roundedMidi) * 100;
    final int noteIndex = roundedMidi % 12;
    final int octave = (roundedMidi ~/ 12) - 1;

    return {
      'note': noteNames[noteIndex],
      'octave': octave,
      'cents': fallbackCents,
    };
  }

  List<double> _applyHanningWindow(List<double> samples) {
    final N = samples.length;
    final windowed = <double>[];

    for (int i = 0; i < N; i++) {
      final window = 0.5 * (1 - cos(2 * pi * i / (N - 1)));
      windowed.add(samples[i] * window);
    }

    return windowed;
  }

  List<double> _autocorrelation(List<double> samples) {
    final int N = samples.length;
    final autocorr = List<double>.filled(N, 0.0);

    for (int lag = 0; lag < N; lag++) {
      for (int i = 0; i < N - lag; i++) {
        autocorr[lag] += samples[i] * samples[i + lag];
      }
      autocorr[lag] /= (N - lag);
    }

    return autocorr;
  }

  Map<String, dynamic> _findFundamentalFrequency(List<double> autocorr, double sampleRate) {
    final int minPeriod = (sampleRate / _maxFrequency).round();
    final int maxPeriod = (sampleRate / _minFrequency).round();

    double maxCorr = 0.0;
    int bestPeriod = 0;

    for (int period = minPeriod; period < maxPeriod && period < autocorr.length; period++) {
      if (autocorr[period] > maxCorr) {
        maxCorr = autocorr[period];
        bestPeriod = period;
      }
    }

    if (bestPeriod == 0 || maxCorr < autocorr[0] * 0.3) {
      return {'frequency': 0.0, 'confidence': 0.0};
    }

    double refinedPeriod = bestPeriod.toDouble();
    if (bestPeriod > 0 && bestPeriod < autocorr.length - 1) {
      final double y1 = autocorr[bestPeriod - 1];
      final double y2 = autocorr[bestPeriod];
      final double y3 = autocorr[bestPeriod + 1];

      final double a = (y1 - 2*y2 + y3) / 2;
      final double b = (y3 - y1) / 2;

      if (a.abs() > 1e-10) {
        final double xMax = -b / (2 * a);
        if (xMax.abs() < 1.0) {
          refinedPeriod = bestPeriod + xMax;
        }
      }
    }

    final double frequency = sampleRate / refinedPeriod;
    final double confidence = maxCorr / autocorr[0];

    return {
      'frequency': frequency,
      'confidence': confidence.clamp(0.0, 1.0),
    };
  }
}