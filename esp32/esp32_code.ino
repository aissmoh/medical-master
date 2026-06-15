#include <Wire.h>
#include "MAX30105.h"
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ===== CONFIGURATION =====
const char* ssid = "ALHN-25AC";
const char* password = "NrjaTAafS8";
const char* serverUrl = "https://birapp.dpdns.org/api/v1/vitals/arduino";
const char* apiKey = "ESP32_Surveillance_2026";
const char* patientId = "6a2eb91a95f5963c254b2fff";
// =========================

#define BUZZER_PIN 18
#define ONE_WIRE_BUS 4

MAX30105 particleSensor;
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
LiquidCrystal_I2C lcd(0x27, 16, 2);

// --- DS18B20 (Temperature) ---
unsigned long lastTempReq = 0;
bool waitingTemp = false;
float rawTemp = -127;
float bodyTemp = 0;
unsigned long lastValidTempTime = 0xFFFFF0;
#define TEMP_TIMEOUT 10000

// --- MAX30105 (BPM / SpO2) ---
bool sensorOK = true;
long irBaseline = 0;
int calibCount = 0;

#define PPG_BUFFER 100
long irBuffer[PPG_BUFFER];
long redBuffer[PPG_BUFFER];
int ppgIndex = 0;
int ppgCount = 0;
unsigned long lastBeat = 0;
float bpmFiltered = 0;
int spo2 = 0;
long irDC = 0;
bool inBeat = false;
bool spo2Valid = false;
bool fingerOn = false;

unsigned long lastSendTime = 0;
#define SEND_INTERVAL 5000
unsigned long lastLcdUpdate = 0;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");

  WiFi.begin(ssid, password);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 10) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  lcd.setCursor(0, 1);
  if (WiFi.status() == WL_CONNECTED) {
    lcd.print("WiFi OK!       ");
    Serial.println("\nWiFi connected");
  } else {
    lcd.print("WiFi SKIP      ");
    Serial.println("\nWiFi skipped");
  }

  delay(1000);
  lcd.clear();

  sensorOK = particleSensor.begin(Wire, I2C_SPEED_STANDARD);
  if (!sensorOK) {
    lcd.print("MAX Error!");
    Serial.println("MAX30102 not found");
  } else {
    particleSensor.setup(0x4F, 4, 3, 100, 411, 16384);
  }

  sensors.begin();
  sensors.setWaitForConversion(false);

  lcd.clear();
  lcd.print("  System Ready  ");
  delay(1000);
  lcd.clear();
}

void readTemperature() {
  unsigned long now = millis();

  if (!waitingTemp) {
    sensors.requestTemperatures();
    lastTempReq = now;
    waitingTemp = true;
    return;
  }

  if (waitingTemp && (now - lastTempReq > 750)) {
    rawTemp = sensors.getTempCByIndex(0);
    waitingTemp = false;

    Serial.print("rawTemp="); Serial.println(rawTemp);

    if (rawTemp >= 30.0 && rawTemp < 42.0) {
      if (bodyTemp == 0) {
        bodyTemp = 36.0;
      } else {
        bodyTemp = bodyTemp * 0.7 + rawTemp * 0.3;
      }
      lastValidTempTime = millis();
      Serial.print("bodyTemp="); Serial.println(bodyTemp);
    }
  }
}

void readMax30105() {
  if (!sensorOK) return;

  unsigned long now = millis();
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();

  if (calibCount < 20) {
    irBaseline += irValue;
    calibCount++;
    if (calibCount == 20) {
      irBaseline = irBaseline / 20;
      Serial.print("Baseline IR="); Serial.println(irBaseline);
    }
  }

  bool fingerNow = (irValue > irBaseline + 3000 || irValue > 20000);

  if (!fingerNow) {
    if (fingerOn) {
      fingerOn = false;
      ppgCount = 0;
      ppgIndex = 0;
      bpmFiltered = 0;
      lastBeat = 0;
      spo2Valid = false;
      spo2 = 0;
    }
    return;
  }

  if (!fingerOn) {
    fingerOn = true;
    ppgCount = 0;
    ppgIndex = 0;
    bpmFiltered = 0;
    lastBeat = 0;
    spo2Valid = false;
    spo2 = 0;
    bodyTemp = 36.0;
    lastValidTempTime = millis();
    lcd.clear();
  }

  irBuffer[ppgIndex] = irValue;
  redBuffer[ppgIndex] = redValue;
  ppgIndex = (ppgIndex + 1) % PPG_BUFFER;
  if (ppgCount < PPG_BUFFER) ppgCount++;

  if (ppgCount >= 25) {
    long minIR = 999999, maxIR = 0, minRED = 999999, maxRED = 0;
    long sumIR = 0, sumRED = 0;
    int start = (ppgIndex - ppgCount + PPG_BUFFER) % PPG_BUFFER;

    for (int i = 0; i < ppgCount; i++) {
      int idx = (start + i) % PPG_BUFFER;
      sumIR += irBuffer[idx];
      sumRED += redBuffer[idx];
      if (irBuffer[idx] < minIR) minIR = irBuffer[idx];
      if (irBuffer[idx] > maxIR) maxIR = irBuffer[idx];
      if (redBuffer[idx] < minRED) minRED = redBuffer[idx];
      if (redBuffer[idx] > maxRED) maxRED = redBuffer[idx];
    }

    long acIR = maxIR - minIR;
    long acRED = maxRED - minRED;
    float dcIR = sumIR / ppgCount;
    float dcRED = sumRED / ppgCount;

    if (acIR > 50 && dcIR > 0 && dcRED > 0) {
      float ratio = (acRED / dcRED) / (acIR / dcIR);
      int spo2Raw = 110 - 25 * ratio;
      if (spo2Raw >= 85 && spo2Raw <= 100) {
        spo2 = (spo2 == 0) ? spo2Raw : spo2 * 0.4 + spo2Raw * 0.6;
        spo2Valid = true;
        Serial.print("SpO2="); Serial.println(spo2);
      }
    }
  }

  irDC = (irDC * 85 + irValue * 15) / 100;
  long irAC = irDC - irValue;
  if (!inBeat) {
    if (irAC > 40 && lastBeat > 0 && now - lastBeat > 200) {
      inBeat = true;
      long delta = now - lastBeat;
      if (delta > 300 && delta < 2000) {
        float instantBPM = 60000.0 / delta;
        if (instantBPM > 35 && instantBPM < 220) {
          bpmFiltered = (bpmFiltered == 0) ? instantBPM : bpmFiltered * 0.7 + instantBPM * 0.3;
        }
      }
      lastBeat = now;
    } else if (irAC > 40 && lastBeat == 0) {
      lastBeat = now;
    }
  } else if (irAC < 5) {
    inBeat = false;
  }
}

void updateLCD() {
  unsigned long now = millis();
  if (now - lastLcdUpdate < 200) return;
  lastLcdUpdate = now;

  bool tempActive = (millis() - lastValidTempTime < TEMP_TIMEOUT);

  lcd.setCursor(0, 0);
  if (fingerOn) {
    lcd.print("BPM:");
    if (bpmFiltered > 35) {
      if (bpmFiltered < 100) lcd.print(" ");
      lcd.print((int)bpmFiltered);
    } else {
      lcd.print(" --");
    }
    lcd.print(" O2:");
    if (spo2Valid) {
      lcd.print(spo2);
      lcd.print("%");
    } else {
      lcd.print("--%");
    }
  } else {
    lcd.print("Finger MAX...   ");
  }

  lcd.setCursor(0, 1);
  lcd.print("Temp:");
  if (tempActive) {
    lcd.print(bodyTemp, 1);
    lcd.print("C");
    if (bodyTemp >= 39.0) lcd.print("FEVER");
    else if (bodyTemp >= 37.8) lcd.print("WARM");
    else lcd.print(" OK");
  } else {
    lcd.print(" --C  OK");
  }
}

void sendToServer() {
  unsigned long now = millis();
  if (!fingerOn || !spo2Valid || bpmFiltered <= 40) return;
  if (now - lastSendTime < SEND_INTERVAL) return;
  lastSendTime = now;

  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", apiKey);

  bool tempActive = (millis() - lastValidTempTime < TEMP_TIMEOUT);
  float sendTemp = tempActive ? bodyTemp : 36.5;

  String jsonPayload = "{";
  jsonPayload += "\"patientId\":\"" + String(patientId) + "\",";
  jsonPayload += "\"heartRate\":" + String((int)bpmFiltered) + ",";
  jsonPayload += "\"oxygenLevel\":" + String(spo2) + ",";
  jsonPayload += "\"temperature\":" + String(sendTemp, 1);
  jsonPayload += "}";

  Serial.print("Sending: "); Serial.println(jsonPayload);

  int httpResponseCode = http.POST(jsonPayload);
  Serial.print("HTTP Response: ");
  Serial.println(httpResponseCode);
  http.end();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastWifiAttempt = 0;
    unsigned long now = millis();
    if (now - lastWifiAttempt > 10000) {
      lastWifiAttempt = now;
      WiFi.disconnect();
      WiFi.begin(ssid, password);
    }
  }

  readTemperature();
  readMax30105();
  updateLCD();
  sendToServer();
}
