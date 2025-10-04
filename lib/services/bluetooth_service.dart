import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class BluetoothService {
  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _temperatureCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningStateSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription? _adapterStateSubscription;

  final _temperatureDataController = StreamController<List<int>>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  Stream<List<int>> get temperatureData => _temperatureDataController.stream;
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  void resetCircuitBreaker() {
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _isConnecting = false;
    _isScanning = false;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add('Reset - Ready to scan');
    }
  }

  Future<void> startScanning() async {
    if (_isScanning || _isConnecting) return;

    _isScanning = true;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add('Searching for TempSpike...');
    }

    try {
      // Check if Bluetooth is available
      if (await fbp.FlutterBluePlus.isSupported == false) {
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add('Bluetooth not supported');
        }
        _isScanning = false;
        return;
      }

      // Monitor Bluetooth adapter state
      _adapterStateSubscription?.cancel();
      _adapterStateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
        if (state == fbp.BluetoothAdapterState.off) {
          if (!_connectionStatusController.isClosed) {
            _connectionStatusController.add('Bluetooth is off - Please enable Bluetooth');
          }
        }
      });

      // Start scanning
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.onScanResults.listen((results) async {
        for (fbp.ScanResult result in results) {
          final deviceName = result.device.platformName;

          if (deviceName.contains('TP960R') || deviceName.contains('TempSpike')) {
            // Cancel scan subscription before connecting
            await _scanSubscription?.cancel();
            _scanSubscription = null;
            await fbp.FlutterBluePlus.stopScan();
            _isScanning = false;
            await _connectToDevice(result.device);
            break;
          }
        }
      });

      // Use cancelWhenScanComplete as per flutter_blue_plus documentation
      if (_scanSubscription != null) {
        fbp.FlutterBluePlus.cancelWhenScanComplete(_scanSubscription!);
      }

      // Handle scan completion
      _scanningStateSubscription?.cancel();
      _scanningStateSubscription = fbp.FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _isScanning && _device == null) {
          _isScanning = false;
          // Restart scanning if no device found
          Future.delayed(const Duration(seconds: 2), () {
            if (_device == null) {
              startScanning();
            }
          });
        }
      });

    } catch (e, stackTrace) {
      // Log full error to console
      print('=== BLUETOOTH SCAN ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('============================');

      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('Scan error: $e');
      }
      _isScanning = false;
    }
  }

  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    if (_isConnecting) return;

    _isConnecting = true;
    _device = device;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add('Connecting...');
    }

    try {
      // Connect to device first to avoid race condition
      await device.connect(timeout: const Duration(seconds: 15));

      // Then set up connection state listener
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen(
        (state) async {
          if (state == fbp.BluetoothConnectionState.disconnected) {
            if (!_connectionStatusController.isClosed) {
              _connectionStatusController.add('Disconnected - Reconnecting...');
            }
            _isConnecting = false;
            await _reconnect();
          } else if (state == fbp.BluetoothConnectionState.connected) {
            if (!_connectionStatusController.isClosed) {
              _connectionStatusController.add('Connected');
            }
            await _discoverServices();
          }
        },
        onError: (error) {
          if (!_connectionStatusController.isClosed) {
            _connectionStatusController.add('Connection state error: $error');
          }
        },
      );

      // Use cancelWhenDisconnected as per flutter_blue_plus documentation
      device.cancelWhenDisconnected(_connectionSubscription!);

      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;

    } catch (e, stackTrace) {
      // Log full error to console
      print('=== BLUETOOTH CONNECTION ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==================================');

      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('Connection error: $e');
      }
      _isConnecting = false;
      _device = null;
      await _reconnect();
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    try {
      // Add timeout to service discovery
      List<fbp.BluetoothService> services = await _device!
          .discoverServices()
          .timeout(const Duration(seconds: 10));

      for (fbp.BluetoothService service in services) {
        for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
          // Look for a characteristic that supports notifications
          if (characteristic.properties.notify) {
            _temperatureCharacteristic = characteristic;

            // Subscribe to notifications
            await characteristic.setNotifyValue(true);

            // Use onValueReceived instead of lastValueStream for notification-only characteristics
            _characteristicSubscription?.cancel();
            _characteristicSubscription = characteristic.onValueReceived.listen(
              (value) {
                if (value.length == 8) {
                  if (!_temperatureDataController.isClosed) {
                    _temperatureDataController.add(value);
                  }
                }
              },
              onError: (error) {
                if (!_connectionStatusController.isClosed) {
                  _connectionStatusController.add('Characteristic error: $error');
                }
              },
            );

            // Use cancelWhenDisconnected for characteristic subscription
            if (_device != null) {
              _device!.cancelWhenDisconnected(_characteristicSubscription!);
            }

            if (!_connectionStatusController.isClosed) {
              _connectionStatusController.add('Ready');
            }
            _isConnecting = false;
            return;
          }
        }
      }

      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('No temperature characteristic found');
      }
      _isConnecting = false;

    } on TimeoutException catch (e, stackTrace) {
      print('=== SERVICE DISCOVERY TIMEOUT ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=================================');

      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('Service discovery timeout');
      }
      _isConnecting = false;
    } catch (e, stackTrace) {
      print('=== SERVICE DISCOVERY ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('===============================');

      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('Service discovery error: $e');
      }
      _isConnecting = false;
    }
  }

  Future<void> _reconnect() async {
    // Guard against concurrent reconnection attempts
    if (_isReconnecting) return;

    // Circuit breaker: limit reconnection attempts
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add('Max reconnection attempts reached. Please restart.');
      }
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    await Future.delayed(const Duration(seconds: 2));

    if (_device != null) {
      await _connectToDevice(_device!);
    } else {
      await startScanning();
    }

    _isReconnecting = false;
  }

  void dispose() {
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    fbp.FlutterBluePlus.stopScan();
    _temperatureDataController.close();
    _connectionStatusController.close();
    _device?.disconnect();
  }
}
