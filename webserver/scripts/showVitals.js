import mongoose from "mongoose";
import dotenv from "dotenv";
dotenv.config();

const vitalSignsSchema = new mongoose.Schema({
  patientId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  assignedNurseId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  oxygenLevel: { value: Number, unit: String, status: String },
  heartRate: { value: Number, unit: String, status: String },
  temperature: { value: Number, unit: String, status: String },
  vertigo: { value: Number, unit: String, status: String },
  bloodPressure: { systolic: Number, diastolic: Number, unit: String, status: String },
  notes: String,
  measuredAt: Date,
  source: String,
}, { timestamps: true, versionKey: false });

const VitalSigns = mongoose.model("VitalSigns", vitalSignsSchema);

async function showVitals() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log("✅ Connected to MongoDB\n");

  const allVitals = await VitalSigns.find().sort({ measuredAt: -1 }).limit(100).lean();

  if (allVitals.length === 0) {
    console.log("❌ Makaynch data f vitalsigns!");
    await mongoose.disconnect();
    return;
  }

  console.log(`=== 📊 VITAL SIGNS: ${allVitals.length} entries ===\n`);

  // --- TABLEAU TEMPERATURE ---
  console.log("=== 🌡️  TEMPERATURE TABLEAU ===");
  console.log("Date                 | Value | Status");
  console.log("-".repeat(45));
  const temps = allVitals.filter(v => v.temperature?.value !== undefined);
  if (temps.length === 0) console.log("(makaynch data)");
  else temps.forEach(v => console.log(
    `${new Date(v.measuredAt).toLocaleString("fr-FR").padEnd(20)}| ${String(v.temperature.value).padStart(5)} | ${v.temperature.status}`
  ));
  console.log();

  // --- TABLEAU OXYGEN ---
  console.log("=== 💨 OXYGEN TABLEAU ===");
  console.log("Date                 | Value  | Status");
  console.log("-".repeat(45));
  const oxy = allVitals.filter(v => v.oxygenLevel?.value !== undefined);
  if (oxy.length === 0) console.log("(makaynch data)");
  else oxy.forEach(v => console.log(
    `${new Date(v.measuredAt).toLocaleString("fr-FR").padEnd(20)}| ${String(v.oxygenLevel.value).padStart(5)}% | ${v.oxygenLevel.status}`
  ));
  console.log();

  // --- TABLEAU HEART RATE ---
  console.log("=== ❤️  CARDIAC (BPM) TABLEAU ===");
  console.log("Date                 | Value  | Status");
  console.log("-".repeat(45));
  const hr = allVitals.filter(v => v.heartRate?.value !== undefined);
  if (hr.length === 0) console.log("(makaynch data)");
  else hr.forEach(v => console.log(
    `${new Date(v.measuredAt).toLocaleString("fr-FR").padEnd(20)}| ${String(v.heartRate.value).padStart(5)} | ${v.heartRate.status}`
  ));
  console.log();

  await mongoose.disconnect();
}

showVitals().catch(err => { console.error("ERROR:", err); process.exit(1); });
