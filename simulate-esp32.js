import axios from "axios";

const SERVER = "http://localhost:5000";

// ===== CONFIGURE ICI =====
const PATIENT_ID = "ID_DU_PATIENT";  // ← mets l'ID du patient ici
const API_KEY = "ESP32_Surveillance_2026";
// =========================

function random(min, max) {
  return Math.round((Math.random() * (max - min) + min) * 10) / 10;
}

async function sendVitals() {
  const data = {
    patientId: PATIENT_ID,
    heartRate: random(60, 100),      // 60-100 bpm
    oxygenLevel: random(95, 100),     // 95-100%
    temperature: random(36.0, 37.5),  // 36.0-37.5 °C
  };

  try {
    const res = await axios.post(`${SERVER}/api/v1/vitals/arduino`, data, {
      headers: { "x-api-key": API_KEY },
    });
    console.log(`[${new Date().toLocaleTimeString()}] ✅ Envoyé: HR=${data.heartRate} SpO2=${data.oxygenLevel}% Temp=${data.temperature}°C`);
  } catch (err) {
    console.error(`❌ Erreur: ${err.response?.data?.message || err.message}`);
  }
}

console.log("🚀 Simulation ESP32 démarrée (envoi toutes les 3 secondes)");
console.log(`   Patient: ${PATIENT_ID}`);
console.log("   Appuie sur Ctrl+C pour arrêter\n");

sendVitals();
setInterval(sendVitals, 3000);
