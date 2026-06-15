import VitalSigns from "../models/vitalSignsModel.js";
import Temperature from "../models/temperatureModel.js";
import OxygenLevel from "../models/oxygenLevelModel.js";
import HeartRate from "../models/heartRateModel.js";
import User from "../models/userModel.js";
import SOSAlert from "../models/sosAlertModel.js";
import mongoose from "mongoose";
import { getIO } from "../socket.js";

// Enregistrer de nouvelles données de signes vitaux (Patient)
export const recordVitalSigns = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const {
      oxygenLevel,
      heartRate,
      temperature,
      vertigo,
      bloodPressure,
      notes,
      measuredAt,
    } = req.body;

    // Vérifier que c'est bien un patient
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les patients peuvent enregistrer des signes vitaux",
      });
    }

    // Vérifier qu'il y a au moins une valeur
    if (
      oxygenLevel === undefined &&
      heartRate === undefined &&
      temperature === undefined &&
      vertigo === undefined &&
      bloodPressure === undefined
    ) {
      return res.status(400).json({
        success: false,
        message: "Au moins une valeur de signe vital est requise",
      });
    }

    // Trouver l'infirmier assigné au patient (s'il existe)
    // Pour l'instant, on va chercher un infirmier qui a des rendez-vous avec ce patient
    // ou on laisse null pour que le système le trouve plus tard
    const assignedNurseId = await findAssignedNurse(patientId);

    // Préparer les données
    const vitalSignsData = {
      patientId,
      assignedNurseId,
      notes: notes || null,
      measuredAt: measuredAt ? new Date(measuredAt) : new Date(),
      source: "manual",
    };

    // Traiter chaque signe vital
    if (oxygenLevel !== undefined) {
      vitalSignsData.oxygenLevel = {
        value: oxygenLevel,
        unit: "%",
        status: "normal",
      };
    }

    if (heartRate !== undefined) {
      vitalSignsData.heartRate = {
        value: heartRate,
        unit: "bpm",
        status: "normal",
      };
    }

    if (temperature !== undefined) {
      vitalSignsData.temperature = {
        value: temperature,
        unit: "°C",
        status: "normal",
      };
    }

    if (vertigo !== undefined) {
      vitalSignsData.vertigo = {
        value: vertigo,
        unit: "rpm",
        status: "normal",
      };
    }

    if (bloodPressure !== undefined) {
      vitalSignsData.bloodPressure = {
        systolic: bloodPressure.systolic,
        diastolic: bloodPressure.diastolic,
        unit: "mmHg",
        status: "normal",
      };
    }

    // Créer l'enregistrement
    const vitalSigns = new VitalSigns(vitalSignsData);

    // Évaluer les statuts
    if (vitalSigns.oxygenLevel) {
      vitalSigns.oxygenLevel.status = vitalSigns.evaluateStatus(
        "oxygenLevel",
        oxygenLevel
      );
    }
    if (vitalSigns.heartRate) {
      vitalSigns.heartRate.status = vitalSigns.evaluateStatus(
        "heartRate",
        heartRate
      );
    }
    if (vitalSigns.temperature) {
      vitalSigns.temperature.status = vitalSigns.evaluateStatus(
        "temperature",
        temperature
      );
    }
    if (vitalSigns.vertigo) {
      vitalSigns.vertigo.status = vitalSigns.evaluateStatus("vertigo", vertigo);
    }
    if (vitalSigns.bloodPressure) {
      vitalSigns.bloodPressure.status = vitalSigns.evaluateStatus(
        "bloodPressure"
      );
    }

    await vitalSigns.save();

    // Sauvegarder aussi dans les tables séparées
    try {
      if (temperature !== undefined) {
        await Temperature.create({ patientId, value: temperature, unit: "°C", status: vitalSigns.temperature.status, measuredAt: vitalSignsData.measuredAt, source: vitalSignsData.source });
      }
      if (oxygenLevel !== undefined) {
        await OxygenLevel.create({ patientId, value: oxygenLevel, unit: "%", status: vitalSigns.oxygenLevel.status, measuredAt: vitalSignsData.measuredAt, source: vitalSignsData.source });
      }
      if (heartRate !== undefined) {
        await HeartRate.create({ patientId, value: heartRate, unit: "bpm", status: vitalSigns.heartRate.status, measuredAt: vitalSignsData.measuredAt, source: vitalSignsData.source });
      }
    } catch (_err) {
      console.warn("Erreur sauvegarde tables séparées (non bloquante):", _err.message);
    }

    // Vérifier s'il y a des alertes
    const alerts = vitalSigns.checkAlerts();

    // Émettre les données en temps réel via Socket.io
    try {
      const io = getIO();
      const vitalData = ensureVitalValues(vitalSigns);
      const payload = {
        patientId,
        data: vitalData,
        measuredAt: vitalSigns.measuredAt,
        alerts,
        source: "manual",
      };

      io.to(`patient:${patientId}`).emit("vitals:update", payload);
      if (assignedNurseId) {
        io.to(`nurse:${assignedNurseId}`).emit("vitals:update", payload);
      }
      io.to("vitals:all").emit("vitals:update", payload);
    } catch (_err) {
      console.warn("Erreur émission socket (non bloquante):", _err.message);
    }

    // Retourner la réponse
    const populatedVitalSigns = await VitalSigns.findById(vitalSigns._id)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    return res.status(201).json({
      success: true,
      message:
        alerts.length > 0
          ? `Signes vitaux enregistrés avec ${alerts.length} alerte(s)`
          : "Signes vitaux enregistrés avec succès",
      data: ensureVitalValues(populatedVitalSigns),
      alerts: alerts,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'enregistrement des signes vitaux",
      error: error.message,
    });
  }
};

// Helper function to ensure vital metrics always have a value field
function ensureVitalValues(data) {
  if (!data) return data;
  const item = data.toJSON ? data.toJSON() : { ...data };
  ['oxygenLevel', 'heartRate', 'temperature', 'vertigo'].forEach(key => {
    if (item[key] && item[key].value === undefined) {
      item[key].value = 0;
    }
  });
  return item;
}

// Obtenir mes dernières données (Patient)
export const getMyLatestVitalSigns = async (req, res) => {
  try {
    const patientId = req.user.userId;

    const vitalSigns = await VitalSigns.getLatestByPatient(patientId);

    if (!vitalSigns) {
      return res.status(404).json({
        success: false,
        message: "Aucune donnée de signes vitaux trouvée",
      });
    }

    return res.status(200).json({
      success: true,
      data: ensureVitalValues(vitalSigns),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des signes vitaux",
      error: error.message,
    });
  }
};

// Obtenir mon historique (Patient)
export const getMyVitalSignsHistory = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { days = 7, startDate, endDate } = req.query;

    const options = {
      limit: parseInt(req.query.limit) || 100,
    };

    if (startDate) options.startDate = startDate;
    if (endDate) options.endDate = endDate;

    // Si pas de dates spécifiques, utiliser le nombre de jours
    if (!startDate && !endDate) {
      const start = new Date();
      start.setDate(start.getDate() - parseInt(days));
      options.startDate = start;
    }

    const history = await VitalSigns.getHistoryByPatient(patientId, options);

    return res.status(200).json({
      success: true,
      count: history.length,
      data: history.map(ensureVitalValues),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération de l'historique",
      error: error.message,
    });
  }
};

// Obtenir les données d'un patient spécifique (Infirmier)
export const getPatientVitalSigns = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { patientId } = req.params;

    // Vérifier que c'est un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux soignants",
      });
    }

    const vitalSigns = await VitalSigns.getLatestByPatient(patientId);

    if (!vitalSigns) {
      return res.status(404).json({
        success: false,
        message: "Aucune donnée trouvée pour ce patient",
      });
    }

    return res.status(200).json({
      success: true,
      data: ensureVitalValues(vitalSigns),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des données",
      error: error.message,
    });
  }
};

// Obtenir l'historique d'un patient (Infirmier)
export const getPatientHistory = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { patientId } = req.params;
    const { days = 30, startDate, endDate, limit = 100 } = req.query;

    // Vérifier que c'est un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux soignants",
      });
    }

    const options = { limit: parseInt(limit) };
    if (startDate) options.startDate = startDate;
    if (endDate) options.endDate = endDate;

    if (!startDate && !endDate) {
      const start = new Date();
      start.setDate(start.getDate() - parseInt(days));
      options.startDate = start;
    }

    const history = await VitalSigns.getHistoryByPatient(patientId, options);

    return res.status(200).json({
      success: true,
      count: history.length,
      period: days,
      data: history.map(ensureVitalValues),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération de l'historique",
      error: error.message,
    });
  }
};

// Helper: extraire l'historique d'un type de signe vital
async function getVitalHistoryByType(patientId, type, days = 7) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - parseInt(days));

  const vitals = await VitalSigns.find({
    patientId,
    measuredAt: { $gte: startDate },
  })
    .sort({ measuredAt: -1 })
    .limit(100);

  return vitals
    .filter((v) => v[type] && v[type].value !== undefined)
    .map((v) => ({
      date: v.measuredAt,
      value: v[type].value,
      unit: v[type].unit,
      status: v[type].status,
    }));
}

// ========== Endpoints Temperature ==========
export const getMyTemperatureHistory = async (req, res) => {
  try {
    const data = await getVitalHistoryByType(req.user.userId, "temperature", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique de température", error: error.message });
  }
};

export const getPatientTemperatureHistory = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await getVitalHistoryByType(req.params.patientId, "temperature", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique de température", error: error.message });
  }
};

// ========== Endpoints Oxygène ==========
export const getMyOxygenHistory = async (req, res) => {
  try {
    const data = await getVitalHistoryByType(req.user.userId, "oxygenLevel", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique d'oxygène", error: error.message });
  }
};

export const getPatientOxygenHistory = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await getVitalHistoryByType(req.params.patientId, "oxygenLevel", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique d'oxygène", error: error.message });
  }
};

// ========== Endpoints Rythme Cardiaque ==========
export const getMyHeartRateHistory = async (req, res) => {
  try {
    const data = await getVitalHistoryByType(req.user.userId, "heartRate", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique du rythme cardiaque", error: error.message });
  }
};

export const getPatientHeartRateHistory = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await getVitalHistoryByType(req.params.patientId, "heartRate", req.query.days);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la récupération de l'historique du rythme cardiaque", error: error.message });
  }
};

// Obtenir les alertes pour l'infirmier
export const getMyAlerts = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { severity, limit = 50 } = req.query;

    // Vérifier que c'est un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux soignants",
      });
    }

    const options = {
      limit: parseInt(limit),
      severity: severity || null,
    };

    const alerts = await VitalSigns.getRecentAlerts(nurseId, options);

    return res.status(200).json({
      success: true,
      count: alerts.length,
      data: alerts,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des alertes",
      error: error.message,
    });
  }
};

// Obtenir les statistiques d'un patient
export const getPatientStats = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { patientId } = req.params;
    const { days = 7 } = req.query;

    // Vérifier que c'est un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux soignants",
      });
    }

    const stats = await VitalSigns.getPatientStats(
      patientId,
      parseInt(days)
    );

    if (!stats) {
      return res.status(404).json({
        success: false,
        message: "Aucune donnée disponible pour cette période",
      });
    }

    return res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du calcul des statistiques",
      error: error.message,
    });
  }
};

// Obtenir tous les patients avec leurs dernières données (Infirmier)
export const getAllPatientsVitalSigns = async (req, res) => {
  try {
    const nurseId = req.user.userId;

    // Vérifier que c'est un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux soignants",
      });
    }

    // Trouver tous les patients qui ont des données
    const latestReadings = await VitalSigns.aggregate([
      {
        $sort: { measuredAt: -1 },
      },
      {
        $group: {
          _id: "$patientId",
          latestReading: { $first: "$$ROOT" },
        },
      },
      {
        $lookup: {
          from: "users",
          localField: "_id",
          foreignField: "_id",
          as: "patient",
        },
      },
      {
        $unwind: "$patient",
      },
      {
        $match: {
          "patient.isPatient": true,
        },
      },
      {
        $project: {
          _id: 0,
          patient: {
            _id: "$patient._id",
            name: "$patient.name",
            email: "$patient.email",
            phone: "$patient.phone",
          },
          latestReading: 1,
        },
      },
    ]);

    return res.status(200).json({
      success: true,
      count: latestReadings.length,
      data: latestReadings.map(r => ({
        ...r,
        latestReading: ensureVitalValues(r.latestReading),
      })),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des données",
      error: error.message,
    });
  }
};

// Fonction utilitaire pour trouver l'infirmier assigné au patient
async function findAssignedNurse(patientId) {
  try {
    // D'abord, vérifier le champ assignedNurse du patient
    const patient = await User.findById(patientId).select("assignedNurse");
    if (patient && patient.assignedNurse) {
      return patient.assignedNurse;
    }

    // Ensuite, chercher dans les rendez-vous
    const Appointment = mongoose.model("Appointment");
    const latestAppointment = await Appointment.findOne({
      patientId,
      status: { $in: ["accepted", "completed"] },
    })
      .sort({ dateTime: -1 })
      .select("nurseId");

    if (latestAppointment && latestAppointment.nurseId) {
      return latestAppointment.nurseId;
    }

    // Si pas de rendez-vous, chercher dans les urgences
    const Emergency = mongoose.model("Emergency");
    const latestEmergency = await Emergency.findOne({
      patientId,
      assignedNurseId: { $ne: null },
    })
      .sort({ createdAt: -1 })
      .select("assignedNurseId");

    if (latestEmergency && latestEmergency.assignedNurseId) {
      return latestEmergency.assignedNurseId;
    }

    return null;
  } catch (error) {
    console.error("Error finding assigned nurse:", error);
    return null;
  }
}

// Supprimer une entrée (Admin ou Patient qui a créé)
export const deleteVitalSignsEntry = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { entryId } = req.params;

    const entry = await VitalSigns.findById(entryId);
    if (!entry) {
      return res.status(404).json({
        success: false,
        message: "Entrée non trouvée",
      });
    }

    // Vérifier les permissions
    const isOwner = entry.patientId.toString() === userId;
    const user = await User.findById(userId);
    const isNurse = user && !user.isPatient;

    if (!isOwner && !isNurse) {
      return res.status(403).json({
        success: false,
        message: "Vous n'êtes pas autorisé à supprimer cette entrée",
      });
    }

    await VitalSigns.findByIdAndDelete(entryId);

    return res.status(200).json({
      success: true,
      message: "Entrée supprimée avec succès",
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la suppression",
      error: error.message,
    });
  }
};

// Recevoir les données de l'Arduino (sans authentification, avec clé API)
export const receiveArduinoData = async (req, res) => {
  try {
    // Vérifier la clé API
    const apiKey = req.headers["x-api-key"] || req.query.apiKey;
    const expectedKey = process.env.ARDUINO_API_KEY;

    if (!expectedKey) {
      console.warn("ARDUINO_API_KEY non configurée dans .env");
    }

    if (expectedKey && apiKey !== expectedKey) {
      return res.status(401).json({
        success: false,
        message: "Clé API invalide",
      });
    }

    const {
      patientId,
      oxygenLevel,
      heartRate,
      temperature,
      vertigo,
      bloodPressure,
      notes,
    } = req.body;

    if (!patientId) {
      return res.status(400).json({
        success: false,
        message: "patientId est requis",
      });
    }

    // Vérifier que le patient existe
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé",
      });
    }

    // Vérifier qu'il y a au moins une valeur
    if (
      oxygenLevel === undefined &&
      heartRate === undefined &&
      temperature === undefined &&
      vertigo === undefined &&
      bloodPressure === undefined
    ) {
      return res.status(400).json({
        success: false,
        message: "Au moins une valeur de signe vital est requise",
      });
    }

    // Trouver l'infirmier assigné au patient
    const assignedNurseId = await findAssignedNurse(patientId);

    // Préparer les données
    const vitalSignsData = {
      patientId,
      assignedNurseId,
      notes: notes || "Données reçues via Arduino",
      measuredAt: new Date(),
      source: "arduino",
    };

    // Traiter chaque signe vital
    if (oxygenLevel !== undefined) {
      vitalSignsData.oxygenLevel = {
        value: oxygenLevel,
        unit: "%",
        status: "normal",
      };
    }

    if (heartRate !== undefined) {
      vitalSignsData.heartRate = {
        value: heartRate,
        unit: "bpm",
        status: "normal",
      };
    }

    if (temperature !== undefined) {
      vitalSignsData.temperature = {
        value: temperature,
        unit: "°C",
        status: "normal",
      };
    }

    if (vertigo !== undefined) {
      vitalSignsData.vertigo = {
        value: vertigo,
        unit: "rpm",
        status: "normal",
      };
    }

    if (bloodPressure !== undefined) {
      vitalSignsData.bloodPressure = {
        systolic: bloodPressure.systolic,
        diastolic: bloodPressure.diastolic,
        unit: "mmHg",
        status: "normal",
      };
    }

    // Créer l'enregistrement
    const vitalSigns = new VitalSigns(vitalSignsData);

    // Évaluer les statuts
    if (vitalSigns.oxygenLevel) {
      vitalSigns.oxygenLevel.status = vitalSigns.evaluateStatus(
        "oxygenLevel",
        oxygenLevel
      );
    }
    if (vitalSigns.heartRate) {
      vitalSigns.heartRate.status = vitalSigns.evaluateStatus(
        "heartRate",
        heartRate
      );
    }
    if (vitalSigns.temperature) {
      vitalSigns.temperature.status = vitalSigns.evaluateStatus(
        "temperature",
        temperature
      );
    }
    if (vitalSigns.vertigo) {
      vitalSigns.vertigo.status = vitalSigns.evaluateStatus("vertigo", vertigo);
    }
    if (vitalSigns.bloodPressure) {
      vitalSigns.bloodPressure.status = vitalSigns.evaluateStatus(
        "bloodPressure"
      );
    }

    await vitalSigns.save();

    // Sauvegarder aussi dans les tables séparées
    try {
      if (temperature !== undefined) {
        await Temperature.create({ patientId, value: temperature, unit: "°C", status: vitalSigns.temperature.status, measuredAt: vitalSignsData.measuredAt, source: "arduino" });
      }
      if (oxygenLevel !== undefined) {
        await OxygenLevel.create({ patientId, value: oxygenLevel, unit: "%", status: vitalSigns.oxygenLevel.status, measuredAt: vitalSignsData.measuredAt, source: "arduino" });
      }
      if (heartRate !== undefined) {
        await HeartRate.create({ patientId, value: heartRate, unit: "bpm", status: vitalSigns.heartRate.status, measuredAt: vitalSignsData.measuredAt, source: "arduino" });
      }
    } catch (_err) {
      console.warn("Erreur sauvegarde tables séparées (non bloquante):", _err.message);
    }

    // Vérifier s'il y a des alertes
    const alerts = vitalSigns.checkAlerts();

    // Si alertes critiques ou warnings, notifier l'infirmier
    if (alerts.length > 0 && assignedNurseId) {
      console.log(
        `ALERT: ${alerts.length} alerte(s) pour le patient ${patientId}`
      );
      console.log("Alerts:", alerts);
    }

    // Émettre les données en temps réel via Socket.io
    try {
      const io = getIO();
      const vitalData = ensureVitalValues(vitalSigns);

      const payload = {
        patientId,
        data: vitalData,
        measuredAt: vitalSigns.measuredAt,
        alerts,
        source: "arduino",
      };

      io.to(`patient:${patientId}`).emit("vitals:update", payload);

      if (assignedNurseId) {
        io.to(`nurse:${assignedNurseId}`).emit("vitals:update", payload);
      }

      io.to("vitals:all").emit("vitals:update", payload);
    } catch (_err) {
      console.warn("Erreur émission socket (non bloquante):", _err.message);
    }

    return res.status(201).json({
      success: true,
      message: "Données Arduino enregistrées avec succès",
      data: ensureVitalValues(vitalSigns),
      alerts: alerts,
    });
  } catch (error) {
    console.error("Erreur Arduino:", error);
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'enregistrement des données Arduino",
      error: error.message,
    });
  }
};
