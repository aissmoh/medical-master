import mongoose from "mongoose";

const temperatureSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: [true, "L'ID du patient est requis"],
  },
  value: {
    type: Number,
    required: [true, "La température est requise"],
    min: [0, "La température ne peut pas être inférieure à 0°C"],
    max: [50, "La température ne peut pas dépasser 50°C"],
  },
  unit: {
    type: String,
    default: "°C",
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

temperatureSchema.index({ patientId: 1, measuredAt: -1 });

const Temperature = mongoose.model("Temperature", temperatureSchema);

export default Temperature;
