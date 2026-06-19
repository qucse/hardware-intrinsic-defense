/*
 * ======================================================================
 * DHT Sensor Node — Man-in-the-Middle (MIMA) Attack Testbed Firmware
 * ============================================================
 *
 * PURPOSE:
 *   This firmware implements an ESP3/ESP32-based DHT11 sensor node used
 *   as a research testbed for studying MIMA attack
 *   via data manipulation in IoT environmental sensing networks.
 *   It is based on / accompanies the published research papers' DOIs 
 *   (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
 *
 *   In NORMAL operation, the node reads temperature and humidity and 
 *   reports them over UDP to a legitimate server (SERVER_IP). When the 
 *   attack is triggered at the (MIMA_SWITCH_PIN), the node enters an 
 *   active MIMA state, where it intercepts the sensor readings and 
 *   deliberately manipulates (offsets) the values by +10 before 
 *   transmission to deceive the monitoring server.
 *
 *   IMPORTANT: This is intentionally vulnerable / malicious-behavior
 *   firmware built for controlled security research and
 *   demonstration purposes ONLY.
 * 
 * THREAT MODEL:
 *   - Legitimate channel: ESP32 -> SERVER_IP (accurate sensor telemetry)
 *   - Adversary channel:  ESP32 -> SERVER_IP (manipulated/false telemetry)
 *   - Trigger:            MIMA_SWITCH_PIN pulled LOW (manually/autonomously)
 *
 * ============================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>
#include "DHT.h"

// --------------------------------------------------------------------
// Pin configuration
// --------------------------------------------------------------------
#define DHTPIN 32           // Data pin for DHT11 sensor
#define DHTTYPE DHT11       // Sensor type definition
#define MIMA_SWITCH_PIN 33   // Manual/Autonomous trigger pin for MIMA attack

// ------------------------------------------------------------------
// Network configuration
// ------------------------------------------------------------------
#define SERVER_PORT 12345           // UDP port used for traffic
#define SERVER_IP "x.x.x.x"         // Legitimate server: trusted destination IP address

const char *ssid = "xxx";               // Wi-Fi SSID — replace with your testbed network
const char *password = "xxx";          // Wi-Fi password — replace with your testbed network credentials

// ------------------------------------------------------------------
// Sensor Configuration & Global Objects
// ------------------------------------------------------------------
DHT dht(DHTPIN, DHTTYPE);
WiFiUDP udp;

// ------------------------------------------------------------------
// Function: startMIMAttack
// Simulates a Man-in-the-Middle attack by looping as long as the 
// trigger pin is LOW. It intercepts real sensor data and applies 
// a mathematical offset to manipulate the reported values.
// ------------------------------------------------------------------
void startMIMAttack() {
  // The attack continues as long as the switch is held in the LOW state
  while (digitalRead(MIMA_SWITCH_PIN) == LOW) {
    Serial.println("Starting man in the middle attack...");
    
    // Uncomment this to amplify the power-consumption signature for attack detection if needed instead of using only the external operational amplifier (OP-AMP) circuit.
    //setCpuFrequencyMhz(XX);

    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();

    if (isnan(temperature) || isnan(humidity)) {
      Serial.println("Failed to read from DHT sensor!");
      return;
    }

    // DATA MANIPULATION: Adding an offset of 10 to the real values
    String data1 = String(temperature + 10.0);
    String data2 = String(humidity + 10.0);

    // Sending the manipulated data to the legitimate server
    Serial.println("Temperature and Humidity Packet Sent: " + data1 + " " + data2);
    udp.beginPacket(SERVER_IP, SERVER_PORT);
    udp.print("Temperature: " + data1 + "\nHumidity: " + data2);
    udp.endPacket();

    delay(2000); // Interval between attack packets
  }
}

void setup() {
  Serial.begin(115200);

  // Sensor and trigger pin setup
  pinMode(DHTPIN, INPUT);
  pinMode(MIMA_SWITCH_PIN, INPUT_PULLUP); // Active-LOW attack trigger

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nConnected to Wi-Fi");

  dht.begin();

  // Initialize UDP socket
  udp.begin(0);
}

void loop() {
  // Baseline frequency for normal operation
  setCpuFrequencyMhz(80);

  // --- Legitimate channel: normal sensor reporting ---
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("[Error] Failed to read from DHT sensor!");
    return;
  }

  String data1 = String(temperature);
  String data2 = String(humidity);

  Serial.println("Temperature and Humidity Packet Sent: " + data1 + " " + data2);
  udp.beginPacket(SERVER_IP, SERVER_PORT);
  udp.print("Temperature: " + data1 + "\nHumidity: " + data2);
  udp.endPacket();

  // --- Attack trigger check ---
  // If the MIMA_SWITCH_PIN is pulled LOW, initiate the MIMA attack sequence
  if (digitalRead(MIMA_SWITCH_PIN) == LOW) {
    delay(400); // Avoid switch bounce
    startMIMAttack();
  }

  delay(2000);
}
