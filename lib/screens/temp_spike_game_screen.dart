import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/temperature_decoder.dart';
import '../widgets/temperature_pie_chart.dart';
import '../widgets/probe_diagram.dart';

class TempSpikeGameScreen extends StatefulWidget {
  const TempSpikeGameScreen({super.key});

  @override
  State<TempSpikeGameScreen> createState() => _TempSpikeGameScreenState();
}

class _TempSpikeGameScreenState extends State<TempSpikeGameScreen>
    with SingleTickerProviderStateMixin {
  final BluetoothService _bluetoothService = BluetoothService();

  StreamSubscription<String>? _connectionStatusSubscription;
  StreamSubscription<List<int>>? _temperatureDataSubscription;

  String _connectionStatus = 'Initializing...';
  double _internalTemp = 0;
  double _ambientTemp = 0;
  double _tempDifferenceF = 0;
  double _tempDifferenceC = 0;
  MatchLevel _matchLevel = MatchLevel.far;
  String _matchStatus = 'Keep trying!';
  int _matchStreak = 0;
  int _bestStreak = 0;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(_glowController);

    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    // Request permissions first and check if granted
    bool permissionsGranted = await _requestPermissions();

    if (!permissionsGranted) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Permissions denied - Please grant Bluetooth permissions';
        });
      }
      return;
    }

    // Listen to connection status with proper subscription management
    _connectionStatusSubscription = _bluetoothService.connectionStatus.listen(
      (status) {
        if (mounted) {
          setState(() {
            _connectionStatus = status;
          });
        }
      },
      onError: (error, stackTrace) {
        print('=== CONNECTION STATUS STREAM ERROR ===');
        print('Error: $error');
        print('Stack trace: $stackTrace');
        print('======================================');

        if (mounted) {
          setState(() {
            _connectionStatus = 'Error: $error';
          });
        }
      },
    );

    // Listen to temperature data with proper subscription management
    _temperatureDataSubscription = _bluetoothService.temperatureData.listen(
      (data) {
        try {
          final tempData = TemperatureDecoder.decode(data);
          if (mounted) {
            setState(() {
              _internalTemp = tempData.internalTempF;
              _ambientTemp = tempData.ambientTempF;
              _tempDifferenceC = tempData.differenceC;
              _tempDifferenceF = tempData.differenceF;
              _matchLevel = tempData.getMatchLevel();
              _matchStatus = tempData.getMatchStatus();

              // Update streak
              if (_matchLevel == MatchLevel.perfect) {
                _matchStreak++;
                if (_matchStreak > _bestStreak) {
                  _bestStreak = _matchStreak;
                }
                // Haptic feedback on match
                HapticFeedback.mediumImpact();
              } else {
                _matchStreak = 0;
              }
            });
          }
        } catch (e, stackTrace) {
          print('=== TEMPERATURE DECODE ERROR ===');
          print('Error: $e');
          print('Stack trace: $stackTrace');
          print('================================');

          if (mounted) {
            setState(() {
              _connectionStatus = 'Temperature decode error';
            });
          }
        }
      },
      onError: (error, stackTrace) {
        print('=== TEMPERATURE DATA STREAM ERROR ===');
        print('Error: $error');
        print('Stack trace: $stackTrace');
        print('=====================================');
      },
    );

    // Start scanning for device
    _bluetoothService.startScanning();
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 12+ (API 31+), we only need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      // Location is not required when using neverForLocation flag
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      print('=== PERMISSION STATUS ===');
      print('Bluetooth Scan: ${statuses[Permission.bluetoothScan]}');
      print('Bluetooth Connect: ${statuses[Permission.bluetoothConnect]}');
      print('=========================');

      // Check if all required permissions are granted
      bool allGranted = statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.bluetoothConnect]!.isGranted;

      // Handle permanently denied permissions
      if (statuses[Permission.bluetoothScan]!.isPermanentlyDenied ||
          statuses[Permission.bluetoothConnect]!.isPermanentlyDenied) {
        // Show dialog to guide user to settings
        if (mounted) {
          _showPermissionDialog();
        }
        return false;
      }

      return allGranted;
    } else if (Platform.isIOS) {
      var status = await Permission.bluetooth.status;
      if (!status.isGranted) {
        status = await Permission.bluetooth.request();
      }
      return status.isGranted;
    }

    return false;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth permissions are required to connect to your TempSpike probe. '
          'Please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_matchLevel) {
      case MatchLevel.perfect:
        return Colors.green.withOpacity(0.3);
      case MatchLevel.close:
        return Colors.yellow.withOpacity(0.2);
      case MatchLevel.far:
        return Colors.red.withOpacity(0.15);
    }
  }

  Color _getStatusColor() {
    switch (_matchLevel) {
      case MatchLevel.perfect:
        return Colors.green;
      case MatchLevel.close:
        return Colors.yellow;
      case MatchLevel.far:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _connectionStatusSubscription?.cancel();
    _temperatureDataSubscription?.cancel();
    _bluetoothService.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: _getBackgroundColor(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Title
                  const SizedBox(height: 20),
                  const Text(
                    'TempSpike Match',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Connection status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _connectionStatus.contains('Ready')
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _connectionStatus.contains('Ready')
                            ? Colors.green
                            : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _connectionStatus.contains('Ready')
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_searching,
                          color: _connectionStatus.contains('Ready')
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _connectionStatus,
                            style: TextStyle(
                              fontSize: 14,
                              color: _connectionStatus.contains('Ready')
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reset button when max attempts reached
                  if (_connectionStatus.contains('Max reconnection'))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _bluetoothService.resetCircuitBreaker();
                          _bluetoothService.startScanning();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Pie charts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TemperaturePieChart(
                        temperature: _internalTemp,
                        label: 'Internal',
                      ),
                      TemperaturePieChart(
                        temperature: _ambientTemp,
                        label: 'Ambient',
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Probe diagram
                  const ProbeDiagram(),

                  const SizedBox(height: 32),

                  // Temperature difference
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(),
                            width: 3,
                          ),
                          boxShadow: _matchLevel == MatchLevel.perfect
                              ? [
                                  BoxShadow(
                                    color: _getStatusColor().withOpacity(_glowAnimation.value),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Δ ${_tempDifferenceF.toStringAsFixed(1)}°F\nΔ ${_tempDifferenceC.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _matchStatus,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Streak counter
                  if (_matchStreak > 0 || _bestStreak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.3),
                            Colors.blue.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.purple,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Streak: $_matchStreak',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_bestStreak > 0) ...[
                            const SizedBox(width: 16),
                            Text(
                              'Best: $_bestStreak',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
