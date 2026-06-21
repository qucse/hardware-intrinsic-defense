/*
 * =======================================================================
 * UDP Receiver — Research Testbed Sink (Legitimate Monitoring Server)
 * =======================================================================
 *
 * PURPOSE:
 *   This firmware implements a UDP-based receiver acting as the central
 *   sink for the research testbed. It is designed to listen for and
 *   log incoming UDP packets from various sensor nodes (Soil, Gas,
 *   Ultrasonic, and DHT) deployed within the experimental network.
 
 * THREAT MODEL (Receiver Perspective):
 *   - Data Source:  All nodes (Legitimate, Attacked, or Compromised).
 *   - Objective:    To provide a centralized, observable record of 
 *                     network traffic for post-attack analysis.
 *
 * =======================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>

// ----------------------------------------------------------------------
// Network configuration
// -----------------------------------------------------------------------
#define SERVER_PORT 12345           // UDP port the receiver is listening on

const char *ssid = "xxx";               // Wi-Fi SSID — replace with your testbed network
const char *password = "xxx";          // Wi-Fi password — replace with your testbed network credentials

// -----------------------------------------------------------------------
// Global Objects
// -----------------------------------------------------------------------
WiFiUDP udp;

// -----------------------------------------------------------------------
// Setup: Initializes Serial, Wi-Fi, and UDP Socket
// -----------------------------------------------------------------------
void setup() {
  Serial.begin(115200);            // Baud rate for monitoring output
  
  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nConnected to Wi-Fi");

  // Print the local IP address (Important for configuring the sensor nodes)
  Serial.print("Receiver IP Address: ");
  Serial.println(WiFi.localIP());

  // Initialize UDP socket and bind to the specified port
  udp.begin(SERVER_PORT);
  Serial.println("UDP Server listening on port " + String(SERVER_PORT));
  Serial.println("---------------------------------------------------");
}

// -----------------------------------------------------------------------
// Loop: Continuous listening for incoming UDP packets
// -----------------------------------------------------------------------
void loop() {
  // Check if a new packet has arrived
  int packetSize = udp.parsePacket();
  
  if (packetSize) {
    // Read the incoming data string
    String incomingData = udp.readString();
    
    // Log the received data to the Serial Monitor for analysis
    Serial.print("[RECEIVED DATA]: ");
    Serial.println(incomingData);
  }

  // Small delay to prevent CPU hogging
  delay(10);
}



