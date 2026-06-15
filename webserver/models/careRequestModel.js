import mongoose from "mongoose";

const careRequestSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    nurseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "refused"],
      default: "pending",
    },
    respondedAt: {
      type: Date,
      default: null,
    },
    reason: {
      type: String,
      default: null,
    },
    urgency: {
      type: String,
      enum: ["low", "medium", "high", "emergency"],
      default: "medium",
    },
    symptoms: {
      type: [String],
      default: [],
    },
    location: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      address: { type: String, default: null },
    },
    preferredContactTime: {
      type: String,
      default: null,
    },
    patientNotes: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

// A patient can only have one pending request at a time
careRequestSchema.index(
  { patientId: 1, status: 1 },
  { unique: true, partialFilterExpression: { status: "pending" } }
);

const CareRequest = mongoose.model("CareRequest", careRequestSchema);

export default CareRequest;
