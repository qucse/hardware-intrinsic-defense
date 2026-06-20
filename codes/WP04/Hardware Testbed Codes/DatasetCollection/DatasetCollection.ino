/*
 * =============================================================================
 * Autonomous Dataset Collection — Power/Voltage Signature Orchestrator
 * =============================================================================
 *
 * PURPOSE:
 *   This firmware acts as an automated orchestrator designed to generate a 
 *   high-precision voltage-signature dataset for training/testing Machine 
 *   Learning models. It automates the injection of attack triggers across 
 *   multiple GPIO pins while simultaneously recording the corresponding 
 *   voltage readings via a high-resolution ADS1115 ADC. 
 *   It is based on / accompanies the published research papers' DOIs 
     (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504).
     
 *   The script systematically cycles through 15 unique permutations of 
 *   attack combinations (Single, Double, Triple, and Quadruple attacks) 
 *   to capture the distinct power-draw "fingerprints" of each event.
 *
 *   DATASET GENERATION PROCESS:
 *   1. Baseline: The system enters a "Normal" state (20 min) with all pins HIGH.
 *   2. Attack Injection: The system triggers a specific pin pattern (20 min).
 *   3. Iteration: The loop repeats through all 15 attack permutations.
 *
 * HARDWARE CONFIGURATION:
 *   - ADC: ADS1115 (16-bit) connected to I2C.
 *   - Monitoring: ADS1115 AIN0 monitors the voltage readings.
 *   - Trigger Pins: GPIO 32 (CCA), 33 (PDA), 25 (DoS), 26 (MIM).
 *
 * DATASET PROFILE:
 *   - Permutations: 15 (ranging from single attack to simultaneous 4-way attack).
 *   - Sampling Rate: 1 sample per second per permutation.
 *   - Total Duration: ~10 hours (for 15 patterns * 2400s per pattern).
 *
 * =============================================================================
 */

#include <Adafruit_ADS1X15.h>

Adafruit_ADS1115 ads; /* Use this for the 16-bit version */
//Adafruit_ADS1015 ads;     /* Use this for the 12-bit version */

// Define GPIO pins
const int pins[] = { 32, 33, 25, 26 };  // CCA, PDA, DoS, MIM

// Function to print voltage and the toggled pin(s)
void printVoltageAndPin(String toggledPins) {
  // Read voltage from the ADC
  int16_t adc0 = ads.readADC_SingleEnded(0);  // Assuming AIN0 for voltage reading
  float volts0 = ads.computeVolts(adc0);

  // Print the voltage and toggled pin numbers
  Serial.print("Voltage: ");
  Serial.println(volts0, 3);  // Print voltage with 3 decimal places
  Serial.print("AttackType: ");
  Serial.println(toggledPins);
}

// Toggling patterns with voltage reading
String togglePins(int pattern) {
  String attackName = "";
  switch (pattern) {
    case 1:  // Pin 32 LOW
      digitalWrite(32, LOW);
      attackName = "CCA";
      break;
    case 2:  // Pin 33 LOW
      digitalWrite(33, LOW);
      attackName = "PDA";
      break;
    case 3:  // Pin 25 LOW
      digitalWrite(25, LOW);
      attackName = "DoS";
      break;
    case 4:  // Pin 26 LOW
      digitalWrite(26, LOW);
      attackName = "MIM";
      break;
    case 5:  // Pins 32 & 33 LOW
      digitalWrite(32, LOW);
      digitalWrite(33, LOW);
      attackName = "CCA&PDA";
      break;
    case 6:  // Pins 32 & 25 LOW
      digitalWrite(32, LOW);
      digitalWrite(25, LOW);
      attackName = "CCA&DoS";
      break;
    case 7:  // Pins 32 & 26 LOW
      digitalWrite(32, LOW);
      digitalWrite(26, LOW);
      attackName = "CCA&MIM";
      break;
    case 8:  // Pins 33 & 25 LOW
      digitalWrite(33, LOW);
      digitalWrite(25, LOW);
      attackName = "PDA&DoS";
      break;
    case 9:  // Pins 33 & 26 LOW
      digitalWrite(33, LOW);
      digitalWrite(26, LOW);
      attackName = "PDA&MIM";
      break;
    case 10:  // Pins 26 & 25 LOW
      digitalWrite(25, LOW);
      digitalWrite(26, LOW);
      attackName = "DoS&MIM";
      break;
    case 11:  // Pins 32, 33 & 25 LOW
      digitalWrite(32, LOW);
      digitalWrite(33, LOW);
      digitalWrite(25, LOW);
      attackName = "CCA&PDA&DoS";
      break;
    case 12:  // Pins 32, 33 & 26 LOW
      digitalWrite(32, LOW);
      digitalWrite(33, LOW);
      digitalWrite(26, LOW);
      attackName = "CCA&PDA&MIM";
      break;
    case 13:  // Pins 32, 26 & 25 LOW
      digitalWrite(32, LOW);
      digitalWrite(25, LOW);
      digitalWrite(26, LOW);
      attackName = "CCA&DoS&MIM";
      break;
    case 14:  // Pins 33, 26 & 25 LOW
      digitalWrite(33, LOW);
      digitalWrite(25, LOW);
      digitalWrite(26, LOW);
      attackName = "PDA&DoS&MIM";
      break;
    case 15:  // Pins 32, 33, 26 & 25 LOW
      digitalWrite(32, LOW);
      digitalWrite(33, LOW);
      digitalWrite(25, LOW);
      digitalWrite(26, LOW);
      attackName = "CCA&PDA&DoS&MIM";
      break;
    default:  // No toggling
      attackName = "Normal";
      break;
  }
  return attackName;
}

// Reset all pins to HIGH (no toggle)
void resetPins() {
  for (int i = 0; i < 4; i++) {
    digitalWrite(pins[i], HIGH);
  }
}

void setup() {
  // Initialize serial communication
  Serial.begin(115200);

  ads.setGain(GAIN_TWOTHIRDS);  // 2/3x gain +/- 6.144V  1 bit = 3mV      0.1875mV (default)
  //ads.setGain(GAIN_ONE);  // 1x gain   +/- 4.096V  1 bit = 2mV      0.125mV

  // Initialize the ADC
  if (!ads.begin()) {
    Serial.println("Failed to initialize ADS.");
    while (1)
      ;
  }

  // Initialize GPIO pins as outputs and set to HIGH
  for (int i = 0; i < 4; i++) {
    pinMode(pins[i], OUTPUT);
    digitalWrite(pins[i], HIGH);  // Set all pins to HIGH initially
  }
}

void loop() {
  // Go through all 15 patterns
  for (int i = 0; i < 15; i++) {
    //1200 iteration ==> 20 min

    // 20 min Normal Period
    resetPins();                      // Reset pins to HIGH (no attack toggling)
    for (int j = 0; j < 1200; j++) {  // Loop for 20 minutes
      printVoltageAndPin("Normal");   // No toggling during this period
      delay(1000);                    // 1 second delay between readings
    }

    // 20 min Attack Period
    String attackName = togglePins(i + 1);  // Get the attack name
    for (int j = 0; j < 1200; j++) {        // Loop for 20 minutes
      printVoltageAndPin(attackName);       // Print voltage and attack name
      delay(1000);                          // 1 second delay between readings
    }
  }
}
