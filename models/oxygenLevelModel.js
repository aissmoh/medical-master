import mongoose from "mongoose";

const oxygenLevelSchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: [true, "L'ID du patient est requis"],
  },
  value: {
    type: Number,
    required: [true, "Le niveau d'oxygène est requis"],
    min: [0, "Le niveau d'oxygène ne peut pas être inférieur à 0"],
    max: [100, "Le niveau d'oxygène ne peut pas dépasser 100"],
  },
  unit: {
    type: String,
    default: "%",
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

oxygenLevelSchema.index({ patientId: 1, measuredAt: -1 });

const OxygenLevel = mongoose.model("OxygenLevel", oxygenLevelSchema);

export default OxygenLevel;
