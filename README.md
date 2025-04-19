# ESP32_Controller

This mobile app enables seamless control and configuration of ESP32-based smart devices using Bluetooth and MQTT protocols. Designed for smart home and automation applications, the app allows both manual and automatic control (e.g., float sensor integration), and supports management of multiple devices.

## ✨ Features

- 🔌 **Control ESP32 Devices Remotely**
  - Manual on/off switch for appliances
  - Real-time status updates via MQTT
- 📶 **Bluetooth-based Wi-Fi Configuration**
  - Set up Wi-Fi credentials for ESP32 directly from the app
- 🔄 **Auto-Control Support**
  - Works with float sensors and other inputs for automatic switching
- 🆔 **Device Pairing via Serial Number**
  - Unique serial numbers ensure secure device linkage
- 📱 **Multi-Device Management**
  - Add and manage multiple devices from a single interface
- 🧠 **MQTT Integration**
  - Fast and efficient real-time communication
- 🌐 **Local Web Server (ESP32)**
  - Device-hosted web interface for fallback/manual access

## 🔧 Setup Instructions

### 📲 Mobile App
1. Clone or download this repository.
2. Open the project in your preferred mobile development framework (e.g., Flutter).
3. Connect your phone to the ESP32 via Bluetooth for Wi-Fi setup.
4. Pair devices using their unique serial number.
5. Use the dashboard to send MQTT commands and monitor status.

### 🔌 ESP32 Firmware
- Ensure your ESP32 device firmware supports:
  - Bluetooth for initial Wi-Fi config
  - MQTT protocol for command and status messages
  - GPIO control for appliance switching
  - Optional: Sensor inputs (e.g., float sensor for auto mode)
- Libraries required (Arduino/ESP-IDF):
  - `WiFi.h`
  - `PubSubClient.h` (for MQTT)
  - `BluetoothSerial.h` (for Bluetooth config)

### 🌐 MQTT Broker
- Host your own broker (e.g., Mosquitto on cloud/VPS) or use public brokers like:
  - `broker.hivemq.com`
- Topics should follow the format:
  ```
  esp32/{serial_number}/command
  esp32/{serial_number}/status
  ```
  
## 🧠 Future Enhancements

- Secure authentication for devices
- Cloud dashboard integration
- OTA firmware updates
- Offline mode with automatic sync

## 🛠️ Tech Stack

- **Frontend**: Flutter
- **Communication**: Bluetooth, MQTT
- **Hardware**: ESP32
- **Backend (optional)**: MQTT Broker

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).

---

Let me know if you'd like it tailored further—like including screenshots, your app name, or specific libraries used in your code.
