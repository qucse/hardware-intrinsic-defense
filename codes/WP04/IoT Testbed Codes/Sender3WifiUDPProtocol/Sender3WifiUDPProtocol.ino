/*
 * ============================================================================
 * Gas Sensor Node — Denial of Servce (DoS) Packet Flooding Testbed Firmware
 * ============================================================================
 *
 * PURPOSE:
 *   This firmware implements an ESP32-based gas sensor node used
 *   as a research testbed for studying Denial of Service (DoS) attacks 
 *   via data flooding in IoT sensor networks. It is based on / accompanies the 
 *   published research papers' DOIs (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
 *
 *   In NORMAL operation, the node reads gas levels and reports them over
 *   UDP to a legitimate server (SERVER_IP). When the attack is triggered 
 *   at the (DOS_SWITCH_PIN), the node enters a continuous, high-volume 
 *   data transmission state (packet flooding) directed at the server, 
 *   simulating a resource exhaustion attack.
 *
 *   IMPORTANT: This is intentionally vulnerable / malicious-behavior
 *   firmware built for controlled security research and
 *   demonstration purposes ONLY.
 * 
 * THREAT MODEL:
 *   - Legitimate channel: ESP32 -> SERVER_IP (trusted monitoring server)
 *   - Adversary channel:  ESP32 -> SERVER_IP (flooded data / resource exhaustion)
 *   - Trigger:            DOS_SWITCH_PIN pulled LOW (manually/autonomously)
 *
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>

// ---------------------------------------------------------------------------
// Pin configuration
// ---------------------------------------------------------------------------
#define GAS_SENSOR_PIN 32    // Analog input from gas sensor
#define DOS_SWITCH_PIN 33    // Manual/Autonomous trigger pin for the DoS attack demo

// ---------------------------------------------------------------------------
// Network configuration
// ---------------------------------------------------------------------------
#define SERVER_PORT 12345           // UDP port used for both legitimate and DoS traffic
#define SERVER_IP "x.x.x.x"         // Legitimate server: trusted destination IP address

const char *ssid = "xxx";      // Wi-Fi SSID — replace with your testbed network
const char *password = "xxx";  // Wi-Fi password — replace with your testbed network credentials

WiFiUDP udp;

// ---------------------------------------------------------------------------
// Function: startPacketFloadingAttack
// Simulates a DoS attack by continuously flooding the legitimate server
// with high-frequency packets until the trigger pin is toggled HIGH.
// ---------------------------------------------------------------------------
void startPacketFloadingAttack() {
  Serial.println("Packet Flooding Attack (DoS) Enabled...");
  
  // Uncomment this to amplify the power-consumption signature for attack detection 
  // if needed instead of using only the external operational amplifier (OP-AMP) circuit.
  //setCpuFrequencyMhz(XX);

  int gasDetected = analogRead(GAS_SENSOR_PIN);
  String data = String(gasDetected);

  while (true) {
    // Sending to the legitimate receiver — this is the target of the flood.
    udp.beginPacket(SERVER_IP, SERVER_PORT);
    udp.print("Gas Level: " + data);
    udp.endPacket();

    Serial.println("Gas Level Packet Sent: " + data);

    // Check if the switch is toggled to stop the attack
    if (digitalRead(DOS_SWITCH_PIN) == HIGH) {
      return; 
    }
  }
}

void setup() {
  Serial.begin(115200);

  // Sensor and trigger pin setup
  pinMode(GAS_SENSOR_PIN, INPUT);
  pinMode(DOS_SWITCH_PIN, INPUT_PULLUP);  // Active-LOW attack trigger

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("Connected to Wi-Fi");

  // Initialize UDP socket (port 0 = let the OS/stack auto-assign a local port)
  udp.begin(0);
}

void loop() {
  setCpuFrequencyMhz(80);  // Fixed baseline so any frequency change during
                           // startPacketFloadingAttack() produces a measurable power-draw signature

  // --- Legitimate channel: normal sensor reporting ---
  int gasDetected = analogRead(GAS_SENSOR_PIN);
  String data = String(gasDetected);

  Serial.println("Gas Level Packet Sent: " + data);
  udp.beginPacket(SERVER_IP, SERVER_PORT);
  udp.print("Gas Level: " + data);
  udp.endPacket();

  // --- Attack trigger check ---
  // If the DOS_SWITCH_PIN was pulled LOW (manually or by the autonomous trigger circuit), 
  // this would start the packet flooding attack.
  if (digitalRead(DOS_SWITCH_PIN) == LOW) {
    delay(400);  // avoids switch/relay bounce on the trigger signal
    startPacketFloadingAttack();
  }

  delay(1200);
}

