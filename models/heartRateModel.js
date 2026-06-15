import mongoose from "mongoose";

const heartRateSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: [true, "L'ID du patient est requis"],
  },
  value: {
    type: Number,
    required: [true, "La fréquence cardiaque est requise"],
    min: [0, "La fréquence cardiaque ne peut pas être négative"],
    max: [300, "La fréquence cardiaque ne peut pas dépasser 300"],
  },
  unit: {
    type: String,
    default: "bpm",
  },
  status: {
    type: String,
    enum: ["normal", "warning", "critical"],
    default: "normal",
  },
  source: {
    type: String,
    enum: ["manual", "device", "automatic", "arduino"],
    default: "manual",
  },
  measuredAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
  versionKey: false,
});

heartRateSchema.index({ patientId: 1, measuredAt: -1 });

const HeartRate = mongoose.model("HeartRate", heartRateSchema);

export default HeartRate;
