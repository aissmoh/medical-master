import mongoose from "mongoose";

const emergencySchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID du patient est requis"],
    },
    location: {
      lat: {
        type: Number,
        required: [true, "La latitude est requise"],
      },
      lng: {
        type: Number,
        required: [true, "La longitude est requise"],
      },
      address: {
        type: String,
        default: null,
      },
    },
    type: {
      type: String,
      enum: [
        "heart_attack",    // Crise cardiaque
        "fall",            // Chute
        "accident",        // Accident
        "breathing",       // Difficulté respiratoire
        "bleeding",        // Saignement
        "other",           // Autre
      ],
      default: "other",
    },
    description: {
      type: String,
      maxlength: [500, "La description ne peut pas dépasser 500 caractères"],
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "in_progress", "resolved", "cancelled"],
      default: "pending",
    },
    vitalSigns: {
      heartRate: {
        type: Number,
        default: null,
      },
      bloodPressure: {
        systolic: { type: Number, default: null },
        diastolic: { type: Number, default: null },
      },
      oxygenLevel: {
        type: Number,
        default: null,
      },
    },
    // Le soignant qui a accepté l'urgence
    assignedNurseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    // Historique des assignations
    assignments: [
      {
        nurseId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        status: {
          type: String,
          enum: ["accepted", "rejected", "timeout"],
        },
        assignedAt: {
          type: Date,
          default: Date.now,
        },
        respondedAt: {
          type: Date,
          default: null,
        },
      },
    ],
    // Temps de réponse
    responseTime: {
      type: Number, // en minutes
      default: null,
    },
    // Notes de l'infirmier
    nurseNotes: {
      type: String,
      maxlength: [1000, "Les notes ne peuvent pas dépasser 1000 caractères"],
      default: null,
    },
    // Urgence résolue
    resolvedAt: {
      type: Date,
      default: null,
    },
    // Raison d'annulation
    cancellationReason: {
      type: String,
      default: null,
    },
    // Notifications envoyées
    notificationsSent: [
      {
        nurseId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
        sentAt: {
          type: Date,
          default: Date.now,
        },
        channel: {
          type: String,
          enum: ["push", "sms", "email"],
          default: "push",
        },
      },
    ],
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Index pour améliorer les performances
emergencySchema.index({ patientId: 1, createdAt: -1 });
emergencySchema.index({ status: 1, createdAt: -1 });
emergencySchema.index({ assignedNurseId: 1, status: 1 });
emergencySchema.index({ "location.lat": 1, "location.lng": 1 });

// Méthode pour calculer la distance (en km) entre deux points GPS
emergencySchema.methods.calculateDistance = function (lat, lng) {
  const R = 6371; // Rayon de la Terre en km
  const dLat = ((this.location.lat - lat) * Math.PI) / 180;
  const dLng = ((this.location.lng - lng) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat * Math.PI) / 180) *
      Math.cos((this.location.lat * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

// Méthode pour trouver les infirmiers disponibles à proximité
emergencySchema.methods.findNearbyNurses = async function (maxDistanceKm = 50) {
  const User = mongoose.model("User");

  // Récupérer tous les infirmiers (non patients)
  const nurses = await User.find({
    isPatient: false,
    isVerified: true,
  }).select("-password -otpCode -otpExpiresAt");

  // Filtrer par distance
  const nearbyNurses = nurses
    .map((nurse) => {
      const distance = this.calculateDistance(
        nurse.location?.lat || 0,
        nurse.location?.lng || 0
      );
      return { nurse, distance };
    })
    .filter(({ distance }) => distance <= maxDistanceKm)
    .sort((a, b) => a.distance - b.distance);

  return nearbyNurses;
};

// Méthode pour accepter l'urgence
emergencySchema.methods.acceptEmergency = async function (nurseId) {
  if (this.status !== "pending") {
    throw new Error("Cette urgence a déjà été prise en charge");
  }

  this.assignedNurseId = nurseId;
  this.status = "accepted";

  const assignment = {
    nurseId,
    status: "accepted",
    assignedAt: new Date(),
    respondedAt: new Date(),
  };

  this.assignments.push(assignment);

  // Calculer le temps de réponse
  this.responseTime = Math.round(
    (assignment.respondedAt - this.createdAt) / 1000 / 60
  );

  await this.save();
  return this;
};

// Méthode pour marquer en cours
emergencySchema.methods.markInProgress = async function () {
  if (this.status !== "accepted") {
    throw new Error("L'urgence doit être acceptée d'abord");
  }

  this.status = "in_progress";
  await this.save();
  return this;
};

// Méthode pour résoudre l'urgence
emergencySchema.methods.resolve = async function (notes = null) {
  if (!["accepted", "in_progress"].includes(this.status)) {
    throw new Error("Statut invalide pour la résolution");
  }

  this.status = "resolved";
  this.resolvedAt = new Date();
  if (notes) {
    this.nurseNotes = notes;
  }

  await this.save();
  return this;
};

// Méthode pour annuler l'urgence
emergencySchema.methods.cancel = async function (reason = null) {
  if (this.status === "resolved") {
    throw new Error("Impossible d'annuler une urgence résolue");
  }

  this.status = "cancelled";
  this.cancellationReason = reason || "Annulée par le patient";

  await this.save();
  return this;
};

// Méthode statique pour obtenir les urgences actives
emergencySchema.statics.getActiveEmergencies = async function () {
  return this.find({
    status: { $in: ["pending", "accepted", "in_progress"] },
  })
    .populate("patientId", "name email phone isPatient")
    .populate("assignedNurseId", "name email phone")
    .sort({ createdAt: -1 });
};

// Méthode statique pour obtenir les urgences d'un patient
emergencySchema.statics.getPatientEmergencies = async function (patientId) {
  return this.find({ patientId })
    .populate("assignedNurseId", "name email phone")
    .sort({ createdAt: -1 });
};

// Méthode statique pour obtenir les urgences assignées à un infirmier
emergencySchema.statics.getNurseEmergencies = async function (nurseId) {
  return this.find({
    $or: [{ assignedNurseId: nurseId }, { "assignments.nurseId": nurseId }],
  })
    .populate("patientId", "name email phone isPatient")
    .sort({ createdAt: -1 });
};

const Emergency = mongoose.model("Emergency", emergencySchema);

export default Emergency;
