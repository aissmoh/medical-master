import mongoose from "mongoose";

const sosAlertSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID du patient est requis"],
    },
    message: {
      type: String,
      default: "Alerte d'urgence",
    },
    type: {
      type: String,
      enum: ["emergency", "vitals_critical", "fall", "direct_alert", "other"],
      default: "emergency",
    },
    status: {
      type: String,
      enum: ["active", "acknowledged", "resolved", "cancelled"],
      default: "active",
    },
    location: {
      type: {
        type: String,
        default: "Point",
      },
      coordinates: {
        type: [Number],
        default: [0, 0],
      },
    },
    acknowledgedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    acknowledgedAt: {
      type: Date,
      default: null,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

const SOSAlert = mongoose.model("SOSAlert", sosAlertSchema);

export default SOSAlert;
