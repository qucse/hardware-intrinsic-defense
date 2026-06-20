/*
 * ============================================================================
 * Motion/Movement Detection Sensor Node — Power Depletion Attack (PDA) Testbed Firmware
 * ============================================================================
 *
 * PURPOSE:
 *   This firmware implements an ESP32-based motion detection sensor node used as a research testbed for studying PDA in IoT motion sensing networks.
 *   It is based on/accompanies the published research papers' DOIs (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
 *
 *   In NORMAL operation, the node detects motion via the digital motion sensor and reports it over UDP to a legitimate server (SERVER_IP). When the attack is manually or autonomously triggered, the ESP32 node connects to an external load, which is a 5-channel IR sensor.
 *   This simulates a compromised sensor node and a power depletion condition.
 *
 *   IMPORTANT: This firmware is intentionally built with malicious behaviors for controlled security research and demonstration purposes ONLY. The attack trigger is based on an external circuit that operates an external load (IR sensor) by receiving a LOW (GND) signal from a Solid State Relay (SSR) module. This signal is connected jointly to the GND of the ESP32 and the IR sensor module, chosen for reproducibility in the lab setting.
 *
 * THREAT MODEL:
 *   - Legitimate channel: ESP32 -> SERVER_IP (trusted monitoring server)
 *   - Power depletion: ESP32 -> Extra-Power Consumption (adversary-controlled)
 *   - Trigger: GND (LOW) activation signal for the IR sensor (manually/autonomously, for demonstration repeatability)
 *
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>

// ---------------------------------------------------------------------------
// Pin configuration
// ---------------------------------------------------------------------------
#define MOTION_SENSOR_PIN 33

// ---------------------------------------------------------------------------
// Network configuration
// ---------------------------------------------------------------------------
#define SERVER_PORT 12345                 // Port to send data to
#define SERVER_IP "x.x.x.x"         // Replace with your Normal receiver's IP address
const char *ssid = "xxx";   // Replace with your Wi-Fi SSID
const char *password = "xxxx";  // Replace with your Wi-Fi password

WiFiUDP udp;


void setup() {
  Serial.begin(115200);

  // Setup the Motion sensor pin
  pinMode(MOTION_SENSOR_PIN, INPUT);
  
  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("Connected to Wi-Fi");

  // Initialize UDP
  udp.begin(0);  // Use 0 for automatic port assignment
}

void loop() {
  setCpuFrequencyMhz(80);  // Fixed baseline so any frequency change during
                           // PDA this would produces a measurable power-draw signature

  int motionDetected = digitalRead(MOTION_SENSOR_PIN);

  String data = String(motionDetected);

  // Sending to normal receiver
  udp.beginPacket(SERVER_IP, SERVER_PORT);
  udp.print("Motion Detected " + data);
  udp.endPacket();

  Serial.println("Motion Detected Packet Sent: " + data);
  delay(2000);
}
