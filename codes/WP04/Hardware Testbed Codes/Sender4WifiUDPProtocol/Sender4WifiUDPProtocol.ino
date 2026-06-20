/*
 * ============================================================================
 * Ultrasonic Distance Sensor Node — Legitimate Monitoring Firmware
 * ============================================================================
 *
 * PURPOSE:
 *   This firmware implements an ESP3-based ultrasonic sensor node used
 *   as a legitimate component within the research testbed. It is designed 
 *   to monitor proximity/distance and report it over UDP to a trusted 
 *   monitoring server (SERVER_IP). 
 *   It is based on / accompanies the published research papers' DOIs 
     (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
 * 
 *   This node serves as a legitimate behavior node in the experimental 
 *   setup, providing standard sensor telemetry without any malicious 
 *   payloads or unauthorized transmissions.
 *
 *   The node uses an HC-SR04 ultrasonic sensor to measure distance and
 *   transmits the results at regular intervals.
 *
 * THREAT MODEL:
 *   - Legitimate channel: ESP32 -> SERVER_IP (trusted monitoring server)
 *   - Note: This specific firmware does not contain any attack vectors; it represents a normal operational state.
 *
 * ============================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>

// ---------------------------------------------------------------------------
// Pin configuration
// ---------------------------------------------------------------------------
#define TRIGGER_PIN 2  // Ultrasonic Trigger pin
#define ECHO_PIN 4     // Ultrasonic Echo pin

// ---------------------------------------------------------------------------
// Network configuration
// ---------------------------------------------------------------------------
#define SERVER_PORT 12345    // UDP port used for legitimate traffic
#define SERVER_IP "x.x.x.x"  // Legitimate server: trusted destination IP address

const char *ssid = "xxx";      // Wi-Fi SSID — replace with your testbed network
const char *password = "xxx";  // Wi-Fi password — replace with your testbed network credentials

// ---------------------------------------------------------------------------
// Sensor Configuration & Global Objects
// ---------------------------------------------------------------------------
WiFiUDP udp;

// ---------------------------------------------------------------------------
// Triggers the ultrasonic sensor and calculates the distance based on
// the time of flight of the ultrasonic pulse.
// ---------------------------------------------------------------------------
float getDistance() {
  digitalWrite(TRIGGER_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGGER_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGGER_PIN, LOW);

  // pulseIn returns the duration in microseconds
  long duration = pulseIn(ECHO_PIN, HIGH);

  // Calculate distance: (duration * speed of sound) / 2
  float distance = duration * 0.034 / 2;
  return distance;
}

void setup() {
  Serial.begin(115200);

  // Sensor pin setup
  pinMode(TRIGGER_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

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
  // Fixed baseline so any frequency change during
  // experimental testing produces a measurable power-draw signature
  setCpuFrequencyMhz(80);

  // --- Legitimate channel: normal sensor reporting ---
  float distance = getDistance();
  String data = "Distance: " + String(distance);

  Serial.println("Distance Packet Sent: " + data);

  udp.beginPacket(SERVER_IP, SERVER_PORT);
  udp.print(data);
  udp.endPacket();

  delay(2000);
}
