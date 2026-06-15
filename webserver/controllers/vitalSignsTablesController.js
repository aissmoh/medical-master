import Temperature from "../models/temperatureModel.js";
import OxygenLevel from "../models/oxygenLevelModel.js";
import HeartRate from "../models/heartRateModel.js";
import User from "../models/userModel.js";

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
};

function evaluateStatus(type, value) {
  const threshold = THRESHOLDS[type];
  if (!threshold) return "normal";

  if (threshold.critical) {
    if (value < threshold.critical.max && value >= threshold.critical.min) return "critical";
    if (threshold.critical.high && value >= threshold.critical.high.min && value <= threshold.critical.high.max) return "critical";
  }
  if (threshold.warning) {
    if (value < threshold.warning.max && value >= threshold.warning.min) return "warning";
    if (threshold.warning.high && value >= threshold.warning.high.min && value <= threshold.warning.high.max) return "warning";
  }
  return "normal";
}

// ========== TEMPERATURE ==========

export const recordTemperature = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { value, measuredAt } = req.body;
    if (value === undefined) return res.status(400).json({ success: false, message: "La température est requise" });

    const temp = await Temperature.create({
      patientId,
      value,
      unit: "°C",
      status: evaluateStatus("temperature", value),
      measuredAt: measuredAt ? new Date(measuredAt) : new Date(),
    });

    return res.status(201).json({ success: true, data: temp });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getMyTemperature = async (req, res) => {
  try {
    const data = await Temperature.find({ patientId: req.user.userId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getPatientTemperature = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await Temperature.find({ patientId: req.params.patientId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

// ========== OXYGEN ==========

export const recordOxygen = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { value, measuredAt } = req.body;
    if (value === undefined) return res.status(400).json({ success: false, message: "Le niveau d'oxygène est requis" });

    const oxy = await OxygenLevel.create({
      patientId,
      value,
      unit: "%",
      status: evaluateStatus("oxygenLevel", value),
      measuredAt: measuredAt ? new Date(measuredAt) : new Date(),
    });

    return res.status(201).json({ success: true, data: oxy });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getMyOxygen = async (req, res) => {
  try {
    const data = await OxygenLevel.find({ patientId: req.user.userId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getPatientOxygen = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await OxygenLevel.find({ patientId: req.params.patientId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

// ========== HEART RATE ==========

export const recordHeartRate = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { value, measuredAt } = req.body;
    if (value === undefined) return res.status(400).json({ success: false, message: "La fréquence cardiaque est requise" });

    const hr = await HeartRate.create({
      patientId,
      value,
      unit: "bpm",
      status: evaluateStatus("heartRate", value),
      measuredAt: measuredAt ? new Date(measuredAt) : new Date(),
    });

    return res.status(201).json({ success: true, data: hr });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getMyHeartRate = async (req, res) => {
  try {
    const data = await HeartRate.find({ patientId: req.user.userId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};

export const getPatientHeartRate = async (req, res) => {
  try {
    const nurse = await User.findById(req.user.userId);
    if (!nurse || nurse.isPatient) return res.status(403).json({ success: false, message: "Accès réservé aux soignants" });
    const data = await HeartRate.find({ patientId: req.params.patientId })
      .sort({ measuredAt: -1 }).limit(parseInt(req.query.limit) || 50);
    return res.status(200).json({ success: true, count: data.length, data });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur", error: error.message });
  }
};
