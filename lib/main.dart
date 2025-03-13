import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  var status = await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.location
  ].request();

  if (status[Permission.bluetooth] != PermissionStatus.granted ||
      status[Permission.bluetoothScan] != PermissionStatus.granted ||
      status[Permission.location] != PermissionStatus.granted) {
    print("Permissions not granted!");
  }
}



// MQTT Service Class
class MqttService {
  final MqttServerClient client = MqttServerClient(
      'xxxxxx.s1.eu.hivemq.cloud', // Replace with your HiveMQ broker
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}');

  final String username = 'test124'; // Replace with your HiveMQ username
  final String password = 'zelda17A@'; // Replace with your HiveMQ password

  MqttService() {
    _setupMqtt();
  }

  Future<void> _setupMqtt() async {
    client.port = 8883;
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext; // Ensure proper TLS security

    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.logging(on: true);

    try {
      await client.connect(username, password);
      print("MQTT Connected Successfully");
    } catch (e) {
      print('MQTT Connection Failed: $e');
      Future.delayed(Duration(seconds: 5), _setupMqtt); // Retry after delay
    }
  }


  void _onConnected() {
    print("MQTT Connected");
  }

  void _onDisconnected() {
    print("MQTT Disconnected! Reconnecting...");
    _setupMqtt();
  }

  void sendCommand(String deviceId, String command) {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      if (builder.payload != null) {
        client.publishMessage("esp32/$deviceId/control", MqttQos.atLeastOnce, builder.payload!);
        print("Sent MQTT Command: $command");
      } else {
        print("Error: MQTT payload is null.");
      }
    } else {
      print("MQTT Not Connected! Trying to Reconnect...");
      _setupMqtt();
    }
  }
}

// Main Application
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: DeviceListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Device List Page (Displays & Manages ESP32 Devices)
class DeviceListPage extends StatefulWidget {
  @override
  _DeviceListPageState createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final MqttService mqttService = MqttService();
  List<String> devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      devices = prefs.getStringList('devices') ?? [];
    });
  }

  void _removeDevice(String serial) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    devices.remove(serial);
    await prefs.setStringList('devices', devices);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ESP32 Device Manager")),
      body: devices.isEmpty
          ? Center(child: Text("No devices added yet", style: TextStyle(color: Colors.black54)))
          : ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          String deviceId = devices[index];
          return Card(
            color: Colors.black12,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text("Device: $deviceId", style: TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.timer, color: Colors.orangeAccent),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.power_settings_new, color: Colors.greenAccent),
                    onPressed: () => mqttService.sendCommand(deviceId, "ON"),
                  ),
                  IconButton(
                    icon: Icon(Icons.power_off, color: Colors.redAccent),
                    onPressed: () => mqttService.sendCommand(deviceId, "OFF"),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _removeDevice(deviceId),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        tooltip: "Add New Device",
        onPressed: () async {
          bool? newDeviceAdded = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BluetoothSetupPage()),
          );
          if (newDeviceAdded == true) {
            _loadDevices();
          }
        },
        child: Icon(Icons.add, color: Colors.black),
      )
    );
  }
}

// Bluetooth Setup Page (For Sending Wi-Fi Credentials)
class BluetoothSetupPage extends StatefulWidget {
  @override
  _BluetoothSetupPageState createState() => _BluetoothSetupPageState();
}
Future<String?> _selectWifiNetwork(BuildContext context) async {
  List<WifiNetwork> wifiList = await WiFiForIoTPlugin.loadWifiList();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Select Wi-Fi Network"),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: wifiList.length,
            itemBuilder: (context, index) {
              String ssid = wifiList[index].ssid ?? "Unknown SSID";
              return ListTile(
                title: Text(ssid),
                onTap: () => Navigator.pop(context, ssid),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}


class _BluetoothSetupPageState extends State<BluetoothSetupPage> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<BluetoothDevice> devices = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    scanDevices();
  }

  void scanDevices() async {
    if (isScanning) return; // Prevent multiple scans
    setState(() {
      isScanning = true;
      devices.clear();
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    // Collect scan results properly
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devices.contains(r.device)) {
          setState(() {
            devices.add(r.device);
          });
        }
      }
    });

    await Future.delayed(Duration(seconds: 5)); // Ensure scan runs
    FlutterBluePlus.stopScan();

    setState(() {
      isScanning = false;
    });

    print("Scan complete: ${devices.length} devices found.");
  }


  Future<String?> _showPasswordDialog(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter Wi-Fi Password"),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(hintText: "Password"),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context, null),
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.pop(context, controller.text),
            ),
          ],
        );
      },
    );
  }


  void sendWifiCredentials(BluetoothDevice device, String ssid, String password) async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          String credentials = jsonEncode({'ssid': ssid, 'password': password});
          await characteristic.write(utf8.encode(credentials));
          print("Wi-Fi Credentials Sent: $credentials");

          // Wait for acknowledgment
          if (characteristic.properties.read) {
            await Future.delayed(Duration(seconds: 2)); // Wait for ESP32 to respond
            List<int> response = await characteristic.read();
            String ack = utf8.decode(response);
            print("ESP32 Acknowledgment: $ack");
          }
          break;
        }
      }
    }
    await device.disconnect();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wi-Fi Setup via Bluetooth"), backgroundColor: Colors.white),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : scanDevices,
            child: isScanning ? CircularProgressIndicator() : Text("Scan for Devices"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    devices[index].name.isNotEmpty ? devices[index].name : "Device: ${devices[index].id}",
                    style: TextStyle(color: Colors.black),
                  ),
                  subtitle: Text("Tap to setup Wi-Fi"),
                  trailing: Icon(Icons.wifi, color: Colors.blueAccent),
                  onTap: () async {
                    String? selectedSSID = await _selectWifiNetwork(context);
                    if (selectedSSID != null) {
                      String? password;
                      if (!selectedSSID.toLowerCase().contains("open")) { // Assume open networks don't need a password
                        password = await _showPasswordDialog(context);
                      }

                      if (password != null || selectedSSID.toLowerCase().contains("open")) {
                        sendWifiCredentials(devices[index], selectedSSID, password ?? "");
                      }
                    }
                  },

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
