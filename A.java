import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  requestPermissions();
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await Permission.bluetooth.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  await Permission.location.request();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.white,
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
  List<String> devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      devices = prefs.getStringList('devices') ?? [];
    });
  }

  void _removeDevice(String serial) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      devices.remove(serial);
      prefs.setStringList('devices', devices);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ESP32 Device Manager"),
        backgroundColor: Colors.blueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: devices.isEmpty
            ? Center(child: Text("No devices added yet", style: TextStyle(color: Colors.black54)))
            : ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.blueGrey[100],
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text("Device: ${devices[index]}", style: TextStyle(color: Colors.black)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.timer, color: Colors.orange),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.power_settings_new, color: Colors.green),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.power_off, color: Colors.red),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDevice(devices[index]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
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
  BluetoothDevice? selectedDevice;
  TextEditingController ssidController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isScanning = false;
  bool isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Wi-Fi Setup via Bluetooth"),
        backgroundColor: Colors.blueAccent,
      ),
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
                BluetoothDevice device = devices[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : "Unknown Device"),
                  subtitle: Text(device.id.toString()),
                  trailing: selectedDevice == device ? Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => selectDevice(device),
                );
              },
            ),
          ),
          if (selectedDevice != null && selectedDevice!.name.contains("ESP32")) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: ssidController,
                decoration: InputDecoration(labelText: "Wi-Fi SSID", border: OutlineInputBorder()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Wi-Fi Password", border: OutlineInputBorder()),
                obscureText: true,
              ),
            ),
            ElevatedButton(
              onPressed: isSending ? null : sendWiFiCredentials,
              child: isSending ? CircularProgressIndicator() : Text("Send Wi-Fi Credentials"),
            ),
          ]
        ],
      ),
    );
  }

  void scanDevices() async {
    devices.clear();
    setState(() => isScanning = true);
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices = results.map((r) => r.device).toList();
        isScanning = false;
      });
    });
  }

  void selectDevice(BluetoothDevice device) {
    setState(() {
      selectedDevice = device;
    });
  }

  void sendWiFiCredentials() async {
    if (selectedDevice == null) return;
    setState(() => isSending = true);
    await Future.delayed(Duration(seconds: 2));
    setState(() => isSending = false);
    Navigator.pop(context, true);
  }
}
