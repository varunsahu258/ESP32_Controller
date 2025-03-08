import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

class MqttService {
  final MqttServerClient client = MqttServerClient(
      'broker.hivemq.com', 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');

  MqttService() {
    _setupMqtt();
  }

  void _setupMqtt() async {
    client.port = 1883;
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.logging(on: true);

    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    try {
      await client.connect();
    } catch (e) {
      print('MQTT Connection Failed: $e');
    }
  }

  void _onConnected() {
    print("MQTT Connected");
  }

  void _onDisconnected() {
    print("MQTT Disconnected");
  }

  void sendCommand(String deviceId, String command) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    client.publishMessage("esp32/$deviceId/control", MqttQos.atLeastOnce, builder.payload!);
    print("Sent MQTT Command: $command");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: DeviceListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
          ? Center(child: Text("No devices added yet", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          String deviceId = devices[index];
          return Card(
            color: Colors.blueGrey[900],
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
        onPressed: () async {
          bool? newDeviceAdded = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BluetoothSetupPage()),
          );
          if (newDeviceAdded == true) {
            _loadDevices();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class BluetoothSetupPage extends StatefulWidget {
  @override
  _BluetoothSetupPageState createState() => _BluetoothSetupPageState();
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
    if (isScanning) return;
    setState(() {
      isScanning = true;
      devices.clear();
    });
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        devices = results.map((r) => r.device).toList();
        isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wi-Fi Setup via Bluetooth"), backgroundColor: Colors.blueAccent),
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
                  title: Text(devices[index].name.isNotEmpty ? devices[index].name : "Unknown Device"),
                  onTap: () => print("Selected: ${devices[index].id}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
