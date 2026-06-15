import mongoose from "mongoose";

const appointmentSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID du patient est requis"],
    },
    nurseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    dateTime: {
      type: Date,
      required: [true, "La date et l'heure du rendez-vous sont requises"],
    },
    duration: {
      type: Number,
      required: [true, "La durée du rendez-vous est requise"],
      min: [15, "La durée minimale est de 15 minutes"],
      max: [480, "La durée maximale est de 8 heures"],
      default: 60,
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected", "completed", "cancelled"],
      default: "pending",
    },
    reason: {
      type: String,
      required: [true, "La raison du rendez-vous est requise"],
      trim: true,
      maxlength: [500, "La raison ne peut pas dépasser 500 caractères"],
    },
    notes: {
      type: String,
      trim: true,
      maxlength: [1000, "Les notes ne peuvent pas dépasser 1000 caractères"],
    },
    location: {
      type: String,
      required: [true, "Le lieu du rendez-vous est requis"],
      trim: true,
      maxlength: [200, "Le lieu ne peut pas dépasser 200 caractères"],
    },
    rejectionReason: {
      type: String,
      trim: true,
      maxlength: [500, "La raison du rejet ne peut pas dépasser 500 caractères"],
    },
    completedAt: {
      type: Date,
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    cancelledBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Virtual pour vérifier si le rendez-vous est dans le passé
appointmentSchema.virtual("isPast").get(function () {
  return new Date() > this.dateTime;
});

// Virtual pour vérifier si le rendez-vous est aujourd'hui
appointmentSchema.virtual("isToday").get(function () {
  const today = new Date();
  const appointmentDate = new Date(this.dateTime);
  return (
    today.getDate() === appointmentDate.getDate() &&
    today.getMonth() === appointmentDate.getMonth() &&
    today.getFullYear() === appointmentDate.getFullYear()
  );
});

// Index pour optimiser les requêtes
appointmentSchema.index({ patientId: 1, status: 1 });
appointmentSchema.index({ nurseId: 1, status: 1 });
appointmentSchema.index({ dateTime: 1 });
appointmentSchema.index({ status: 1, dateTime: 1 });

// Middleware pour valider que le patient est bien un patient
appointmentSchema.pre("save", async function () {
  if (this.isNew) {
    const User = mongoose.model("User");
    const patient = await User.findById(this.patientId);
    if (!patient || !patient.isPatient) {
      throw new Error("Le patient spécifié n'est pas valide");
    }
  }
});

// Middleware pour valider que l'infirmier est bien un infirmier
appointmentSchema.pre("save", async function () {
  if (this.isModified("nurseId") && this.nurseId) {
    const User = mongoose.model("User");
    const nurse = await User.findById(this.nurseId);
    if (!nurse || nurse.isPatient) {
      throw new Error("L'infirmier spécifié n'est pas valide");
    }
  }
});

const Appointment = mongoose.model("Appointment", appointmentSchema);

export default Appointment;
