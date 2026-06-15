import mongoose from "mongoose";

const vitalSignsSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID du patient est requis"],
    },
    // Infirmier assigné au patient (pour les notifications)
    assignedNurseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    // Signes vitaux
    oxygenLevel: {
      value: {
        type: Number,
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
    },
    heartRate: {
      value: {
        type: Number,
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
    },
    temperature: {
      value: {
        type: Number,
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
    },
    // Vertige / Équilibre (RPM - rotations par minute)
    vertigo: {
      value: {
        type: Number,
        min: [0, "Le vertige ne peut pas être négatif"],
        max: [100, "Le vertige ne peut pas dépasser 100"],
      },
      unit: {
        type: String,
        default: "rpm",
      },
      status: {
        type: String,
        enum: ["normal", "warning", "critical"],
        default: "normal",
      },
    },
    // Pression artérielle (optionnel)
    bloodPressure: {
      systolic: {
        type: Number,
        min: [50, "La pression systolique ne peut pas être inférieure à 50"],
        max: [250, "La pression systolique ne peut pas dépasser 250"],
      },
      diastolic: {
        type: Number,
        min: [30, "La pression diastolique ne peut pas être inférieure à 30"],
        max: [150, "La pression diastolique ne peut pas dépasser 150"],
      },
      unit: {
        type: String,
        default: "mmHg",
      },
      status: {
        type: String,
        enum: ["normal", "warning", "critical"],
        default: "normal",
      },
    },
    // Notes du patient
    notes: {
      type: String,
      maxlength: [500, "Les notes ne peuvent pas dépasser 500 caractères"],
      default: null,
    },
    // Date et heure de la mesure
    measuredAt: {
      type: Date,
      default: Date.now,
    },
    // Source de la mesure (manual, device)
    source: {
      type: String,
      enum: ["manual", "device", "automatic", "arduino"],
      default: "manual",
    },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.__v;
        // Ensure every metric has a value field (for legacy data)
        ['oxygenLevel', 'heartRate', 'temperature', 'vertigo'].forEach(key => {
          if (ret[key] && ret[key].value === undefined) {
            ret[key].value = 0;
          }
        });
        return ret;
      },
    },
  }
);

// Index pour améliorer les performances
vitalSignsSchema.index({ patientId: 1, measuredAt: -1 });
vitalSignsSchema.index({ patientId: 1, createdAt: -1 });
vitalSignsSchema.index({ assignedNurseId: 1, "oxygenLevel.status": 1 });
vitalSignsSchema.index({ assignedNurseId: 1, "heartRate.status": 1 });

// Seuils d'alerte
const THRESHOLDS = {
  oxygenLevel: {
    critical: { min: 0, max: 90 },
    warning: { min: 90, max: 95 },
    normal: { min: 95, max: 100 },
  },
  heartRate: {
    critical: { min: 0, max: 50, high: { min: 120, max: 300 } },
    warning: { min: 50, max: 60, high: { min: 100, max: 120 } },
    normal: { min: 60, max: 100 },
  },
  temperature: {
    critical: { min: 0, max: 35, high: { min: 39, max: 45 } },
    warning: { min: 35, max: 36, high: { min: 37.5, max: 39 } },
    normal: { min: 36, max: 37.5 },
  },
  vertigo: {
    critical: { min: 30, max: 100 },
    warning: { min: 20, max: 30 },
    normal: { min: 0, max: 20 },
  },
  bloodPressure: {
    systolic: {
      critical: { min: 0, max: 90, high: { min: 180, max: 250 } },
      warning: { min: 90, max: 110, high: { min: 140, max: 180 } },
      normal: { min: 110, max: 140 },
    },
    diastolic: {
      critical: { min: 0, max: 60, high: { min: 110, max: 150 } },
      warning: { min: 60, max: 70, high: { min: 90, max: 110 } },
      normal: { min: 70, max: 90 },
    },
  },
};

// Méthode pour évaluer le statut d'une valeur
vitalSignsSchema.methods.evaluateStatus = function (type, value) {
  const threshold = THRESHOLDS[type];
  if (!threshold) return "normal";

  if (type === "bloodPressure") {
    // Évaluation spéciale pour la pression artérielle
    const systolicStatus = this._evaluateSingleValue(
      this.bloodPressure.systolic,
      threshold.systolic
    );
    const diastolicStatus = this._evaluateSingleValue(
      this.bloodPressure.diastolic,
      threshold.diastolic
    );

    // Retourner le pire des deux
    if (systolicStatus === "critical" || diastolicStatus === "critical")
      return "critical";
    if (systolicStatus === "warning" || diastolicStatus === "warning")
      return "warning";
    return "normal";
  }

  // Pour le vertige, plus c'est élevé, plus c'est critique
  if (type === "vertigo") {
    if (value >= THRESHOLDS.vertigo.critical.min) return "critical";
    if (value >= THRESHOLDS.vertigo.warning.min) return "warning";
    return "normal";
  }

  return this._evaluateSingleValue(value, threshold);
};

vitalSignsSchema.methods._evaluateSingleValue = function (value, threshold) {
  if (!threshold) return "normal";

  // Vérifier les seuils critiques
  if (threshold.critical) {
    if (value < threshold.critical.max && value >= threshold.critical.min) {
      return "critical";
    }
    // Vérifier le seuil critique haut (pour certains types)
    if (threshold.critical.high) {
      if (
        value >= threshold.critical.high.min &&
        value <= threshold.critical.high.max
      ) {
        return "critical";
      }
    }
  }

  // Vérifier les seuils d'avertissement
  if (threshold.warning) {
    if (value < threshold.warning.max && value >= threshold.warning.min) {
      return "warning";
    }
    if (threshold.warning.high) {
      if (
        value >= threshold.warning.high.min &&
        value <= threshold.warning.high.max
      ) {
        return "warning";
      }
    }
  }

  return "normal";
};

// Méthode pour vérifier s'il y a des alertes
vitalSignsSchema.methods.checkAlerts = function () {
  const alerts = [];

  if (this.oxygenLevel.status === "critical") {
    alerts.push({
      type: "oxygenLevel",
      severity: "critical",
      message: `Niveau d'oxygène critique: ${this.oxygenLevel.value}%`,
      value: this.oxygenLevel.value,
    });
  } else if (this.oxygenLevel.status === "warning") {
    alerts.push({
      type: "oxygenLevel",
      severity: "warning",
      message: `Niveau d'oxygène bas: ${this.oxygenLevel.value}%`,
      value: this.oxygenLevel.value,
    });
  }

  if (this.heartRate.status === "critical") {
    alerts.push({
      type: "heartRate",
      severity: "critical",
      message: `Fréquence cardiaque anormale: ${this.heartRate.value} bpm`,
      value: this.heartRate.value,
    });
  } else if (this.heartRate.status === "warning") {
    alerts.push({
      type: "heartRate",
      severity: "warning",
      message: `Fréquence cardiaque élevée: ${this.heartRate.value} bpm`,
      value: this.heartRate.value,
    });
  }

  if (this.temperature.status === "critical") {
    alerts.push({
      type: "temperature",
      severity: "critical",
      message: `Température anormale: ${this.temperature.value}°C`,
      value: this.temperature.value,
    });
  } else if (this.temperature.status === "warning") {
    alerts.push({
      type: "temperature",
      severity: "warning",
      message: `Température élevée: ${this.temperature.value}°C`,
      value: this.temperature.value,
    });
  }

  if (this.vertigo.status === "critical") {
    alerts.push({
      type: "vertigo",
      severity: "critical",
      message: `Vertige critique détecté: ${this.vertigo.value} rpm`,
      value: this.vertigo.value,
    });
  } else if (this.vertigo.status === "warning") {
    alerts.push({
      type: "vertigo",
      severity: "warning",
      message: `Vertige élevé: ${this.vertigo.value} rpm`,
      value: this.vertigo.value,
    });
  }

  return alerts;
};

// Méthode statique pour obtenir les dernières valeurs d'un patient
vitalSignsSchema.statics.getLatestByPatient = async function (patientId) {
  return this.findOne({ patientId })
    .sort({ measuredAt: -1 })
    .populate("patientId", "name email phone isPatient")
    .populate("assignedNurseId", "name email phone");
};

// Méthode statique pour obtenir l'historique d'un patient
vitalSignsSchema.statics.getHistoryByPatient = async function (
  patientId,
  options = {}
) {
  const { startDate, endDate, limit = 100 } = options;

  const query = { patientId };
  if (startDate || endDate) {
    query.measuredAt = {};
    if (startDate) query.measuredAt.$gte = new Date(startDate);
    if (endDate) query.measuredAt.$lte = new Date(endDate);
  }

  return this.find(query)
    .sort({ measuredAt: -1 })
    .limit(limit)
    .populate("patientId", "name email")
    .populate("assignedNurseId", "name email");
};

// Méthode statique pour obtenir les alertes récentes
vitalSignsSchema.statics.getRecentAlerts = async function (
  nurseId,
  options = {}
) {
  const { limit = 50, severity = null } = options;

  const query = { assignedNurseId: nurseId };

  // Construire la requête pour trouver les signes vitaux critiques/avertissements
  const orConditions = [
    { "oxygenLevel.status": { $in: ["critical", "warning"] } },
    { "heartRate.status": { $in: ["critical", "warning"] } },
    { "temperature.status": { $in: ["critical", "warning"] } },
    { "vertigo.status": { $in: ["critical", "warning"] } },
    { "bloodPressure.status": { $in: ["critical", "warning"] } },
  ];

  if (severity) {
    // Filtrer par sévérité spécifique
    const statusFilter = severity === "critical" ? "critical" : "warning";
    query.$or = orConditions.map((condition) => {
      const key = Object.keys(condition)[0];
      return { [key]: statusFilter };
    });
  } else {
    query.$or = orConditions;
  }

  return this.find(query)
    .sort({ measuredAt: -1 })
    .limit(limit)
    .populate("patientId", "name email phone")
    .populate("assignedNurseId", "name email phone");
};

// Méthode statique pour obtenir les statistiques d'un patient
vitalSignsSchema.statics.getPatientStats = async function (
  patientId,
  days = 7
) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const readings = await this.find({
    patientId,
    measuredAt: { $gte: startDate },
  }).sort({ measuredAt: 1 });

  if (readings.length === 0) {
    return null;
  }

  const stats = {
    totalReadings: readings.length,
    period: days,
    oxygenLevel: calculateStats(readings.map((r) => r.oxygenLevel?.value)),
    heartRate: calculateStats(readings.map((r) => r.heartRate?.value)),
    temperature: calculateStats(readings.map((r) => r.temperature?.value)),
    vertigo: calculateStats(readings.map((r) => r.vertigo?.value)),
    criticalAlerts: readings.filter(
      (r) =>
        r.oxygenLevel?.status === "critical" ||
        r.heartRate?.status === "critical" ||
        r.temperature?.status === "critical" ||
        r.vertigo?.status === "critical"
    ).length,
    warningAlerts: readings.filter(
      (r) =>
        r.oxygenLevel?.status === "warning" ||
        r.heartRate?.status === "warning" ||
        r.temperature?.status === "warning" ||
        r.vertigo?.status === "warning"
    ).length,
  };

  return stats;
};

// Fonction utilitaire pour calculer les statistiques
function calculateStats(values) {
  const validValues = values.filter((v) => v !== null && v !== undefined);
  if (validValues.length === 0) return null;

  const sum = validValues.reduce((a, b) => a + b, 0);
  const avg = sum / validValues.length;
  const min = Math.min(...validValues);
  const max = Math.max(...validValues);

  return {
    average: Math.round(avg * 100) / 100,
    min,
    max,
    count: validValues.length,
  };
}

const VitalSigns = mongoose.model("VitalSigns", vitalSignsSchema);

export default VitalSigns;
