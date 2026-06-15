import User from "../models/userModel.js";
import VitalSigns from "../models/vitalSignsModel.js";
import HeartRate from "../models/heartRateModel.js";
import Temperature from "../models/temperatureModel.js";
import OxygenLevel from "../models/oxygenLevelModel.js";
import SOSAlert from "../models/sosAlertModel.js";
import CareRequest from "../models/careRequestModel.js";

// @desc    Get all patients assigned to logged in nurse
// @route   GET /api/v1/nurse/my-patients
// @access  Private (Nurse only)
export const getMyPatients = async (req, res) => {
  try {
    // Verify user is a garde malade (not a patient)
    if (req.user.isPatient === true) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé. Seuls les gardes malades peuvent voir leurs patients.",
      });
    }

    // Find all patients assigned to this garde malade
    const patients = await User.find({
      assignedNurse: req.user.userId,
      isPatient: true,
    }).select("-password");

    // Get latest vital signs for each patient
    const patientsWithVitals = await Promise.all(
      patients.map(async (patient) => {
        let latestVitals = await VitalSigns.findOne({
          patientId: patient._id,
        })
          .sort({ measuredAt: -1 })
          .lean();

        // Fallback: build latestVitals from individual tables
        if (!latestVitals) {
          const [hr, temp, oxy] = await Promise.all([
            HeartRate.findOne({ patientId: patient._id }).sort({ measuredAt: -1 }).lean(),
            Temperature.findOne({ patientId: patient._id }).sort({ measuredAt: -1 }).lean(),
            OxygenLevel.findOne({ patientId: patient._id }).sort({ measuredAt: -1 }).lean(),
          ]);

          const timestamps = [hr?.measuredAt, temp?.measuredAt, oxy?.measuredAt]
            .filter(Boolean)
            .map(d => d.getTime());

          if (timestamps.length > 0) {
            latestVitals = {
              heartRate: hr ? { value: hr.value } : null,
              temperature: temp ? { value: temp.value } : null,
              oxygenLevel: oxy ? { value: oxy.value } : null,
              measuredAt: new Date(Math.max(...timestamps)),
            };
          }
        }

        return {
          ...patient.toObject(),
          latestVitals,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: patientsWithVitals.length,
      patients: patientsWithVitals,
    });
  } catch (error) {
    console.error("Error in getMyPatients:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des patients",
      error: error.message,
    });
  }
};

// @desc    Get detailed information about a specific patient
// @route   GET /api/v1/nurse/patient/:patientId/details
// @access  Private (Nurse only)
export const getPatientDetails = async (req, res) => {
  try {
    const { patientId } = req.params;

    // Verify user is nurse
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé. Seuls les infirmiers peuvent voir les détails des patients.",
      });
    }

    // Find patient and verify they're assigned to this nurse
    const patient = await User.findOne({
      _id: patientId,
      assignedNurse: req.user._id,
      isPatient: true,
    }).select("-password");

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé ou non assigné à cet infirmier",
      });
    }

    // Get patient's vital signs history
    const vitalsHistory = await VitalSigns.find({
      patientId: patientId,
    })
      .sort({ measuredAt: -1 })
      .limit(50);

    // Get active alerts for this patient
    const activeAlerts = await SOSAlert.find({
      patientId: patientId,
      status: "active",
    }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      patient,
      vitalsHistory,
      activeAlerts,
    });
  } catch (error) {
    console.error("Error in getPatientDetails:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des détails du patient",
      error: error.message,
    });
  }
};

// @desc    Get active SOS alerts for nurse's patients
// @route   GET /api/v1/nurse/alerts
// @access  Private (Nurse only)
export const getActiveAlerts = async (req, res) => {
  try {
    // Verify user is nurse
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé. Seuls les infirmiers peuvent voir les alertes.",
      });
    }

    // Get all patients assigned to this nurse
    const patients = await User.find({
      assignedNurse: req.user._id,
      isPatient: true,
    }).select("_id name");

    const patientIds = patients.map((p) => p._id);

    // Get active alerts for these patients
    const alerts = await SOSAlert.find({
      patientId: { $in: patientIds },
      status: "active",
    })
      .populate("patientId", "name roomInfo")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: alerts.length,
      alerts,
    });
  } catch (error) {
    console.error("Error in getActiveAlerts:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des alertes",
      error: error.message,
    });
  }
};

// @desc    Acknowledge an alert
// @route   PUT /api/v1/nurse/alerts/:alertId/acknowledge
// @access  Private (Nurse only)
export const acknowledgeAlert = async (req, res) => {
  try {
    const { alertId } = req.params;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const alert = await SOSAlert.findByIdAndUpdate(
      alertId,
      {
        status: "acknowledged",
        acknowledgedBy: req.user._id,
        acknowledgedAt: new Date(),
      },
      { new: true }
    );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: "Alerte non trouvée",
      });
    }

    res.status(200).json({
      success: true,
      message: "Alerte reconnue",
      alert,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Resolve an alert
// @route   PUT /api/v1/nurse/alerts/:alertId/resolve
// @access  Private (Nurse only)
export const resolveAlert = async (req, res) => {
  try {
    const { alertId } = req.params;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const alert = await SOSAlert.findByIdAndUpdate(
      alertId,
      {
        status: "resolved",
        resolvedBy: req.user._id,
        resolvedAt: new Date(),
      },
      { new: true }
    );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: "Alerte non trouvée",
      });
    }

    res.status(200).json({
      success: true,
      message: "Alerte résolue",
      alert,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Create SOS alert (for patient emergency button)
// @route   POST /api/v1/nurse/sos
// @access  Private
export const createSOSAlert = async (req, res) => {
  try {
    const { patientId, message, type = "emergency" } = req.body;

    // Verify the patient belongs to this nurse
    const patient = await User.findOne({
      _id: patientId,
      assignedNurse: req.user._id,
    });

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé",
      });
    }

    const alert = await SOSAlert.create({
      patientId,
      message,
      type,
      status: "active",
      location: patient.location,
    });

    res.status(201).json({
      success: true,
      message: "Alerte SOS créée",
      alert,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur lors de la création de l'alerte",
      error: error.message,
    });
  }
};

// @desc    Get alert history
// @route   GET /api/v1/nurse/alerts/history
// @access  Private (Nurse only)
export const getAlertHistory = async (req, res) => {
  try {
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    // Get all patients assigned to this nurse
    const patients = await User.find({
      assignedNurse: req.user._id,
      isPatient: true,
    }).select("_id");

    const patientIds = patients.map((p) => p._id);

    // Get all alerts (not just active)
    const alerts = await SOSAlert.find({
      patientId: { $in: patientIds },
    })
      .populate("patientId", "name roomInfo")
      .sort({ createdAt: -1 })
      .limit(100);

    res.status(200).json({
      success: true,
      count: alerts.length,
      alerts,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Get patient vital signs chart data
// @route   GET /api/v1/nurse/patient/:patientId/vitals/chart
// @access  Private (Nurse only)
export const getPatientVitalsChart = async (req, res) => {
  try {
    const { patientId } = req.params;
    const { days = 7 } = req.query;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    // Verify patient belongs to nurse
    const patient = await User.findOne({
      _id: patientId,
      assignedNurse: req.user._id,
    });

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé",
      });
    }

    // Get vitals for the last X days
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(days));

    const vitals = await VitalSigns.find({
      patientId: patientId,
      measuredAt: { $gte: startDate },
    }).sort({ measuredAt: 1 });

    let chartData;

    if (vitals.length > 0) {
      chartData = vitals.map((v) => ({
        date: v.measuredAt,
        heartRate: v.heartRate?.value || null,
        temperature: v.temperature?.value || null,
        oxygenLevel: v.oxygenLevel?.value || null,
      }));
    } else {
      // Fallback: merge individual tables chronologically
      const [hrs, temps, oxys] = await Promise.all([
        HeartRate.find({ patientId, measuredAt: { $gte: startDate } }).sort({ measuredAt: 1 }).lean(),
        Temperature.find({ patientId, measuredAt: { $gte: startDate } }).sort({ measuredAt: 1 }).lean(),
        OxygenLevel.find({ patientId, measuredAt: { $gte: startDate } }).sort({ measuredAt: 1 }).lean(),
      ]);

      const merged = new Map();
      for (const r of hrs) {
        const key = r.measuredAt.getTime();
        if (!merged.has(key)) merged.set(key, { date: r.measuredAt, heartRate: null, temperature: null, oxygenLevel: null });
        merged.get(key).heartRate = r.value;
      }
      for (const r of temps) {
        const key = r.measuredAt.getTime();
        if (!merged.has(key)) merged.set(key, { date: r.measuredAt, heartRate: null, temperature: null, oxygenLevel: null });
        merged.get(key).temperature = r.value;
      }
      for (const r of oxys) {
        const key = r.measuredAt.getTime();
        if (!merged.has(key)) merged.set(key, { date: r.measuredAt, heartRate: null, temperature: null, oxygenLevel: null });
        merged.get(key).oxygenLevel = r.value;
      }

      chartData = [...merged.values()].sort((a, b) => a.date - b.date);
    }

    res.status(200).json({
      success: true,
      patientId,
      days: parseInt(days),
      data: chartData,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Get pending care requests for the logged-in garde malade
// @route   GET /api/v1/nurse/pending-requests
// @access  Private (Nurse only)
export const getPendingRequests = async (req, res) => {
  try {
    const nurseId = req.user.userId;

    // Verify user is a garde malade
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Acc\u00e8s r\u00e9serv\u00e9 aux gardes malades.",
      });
    }

    const requests = await CareRequest.find({
      nurseId,
      status: "pending",
    })
      .populate("patientId", "name email phone groupeSanguin")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: requests.length,
      requests,
    });
  } catch (error) {
    console.error("Error getting pending requests:", error);
    res.status(500).json({
      success: false,
      message: "Erreur serveur.",
      error: error.message,
    });
  }
};

// @desc    Accept or refuse a care request
// @route   PATCH /api/v1/nurse/respond-request/:requestId
// @access  Private (Nurse only)
export const respondToRequest = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { requestId } = req.params;
    const { action } = req.body; // "accept" or "refuse"

    if (!action || !['accept', 'refuse'].includes(action)) {
      return res.status(400).json({
        success: false,
        message: "L'action doit \u00eatre 'accept' ou 'refuse'.",
      });
    }

    // Verify user is a garde malade
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Acc\u00e8s r\u00e9serv\u00e9 aux gardes malades.",
      });
    }

    // Find the care request
    const careRequest = await CareRequest.findOne({
      _id: requestId,
      nurseId,
      status: "pending",
    });

    if (!careRequest) {
      return res.status(404).json({
        success: false,
        message: "Demande non trouv\u00e9e ou d\u00e9j\u00e0 trait\u00e9e.",
      });
    }

    if (action === "accept") {
      // Update request status
      careRequest.status = "accepted";
      careRequest.respondedAt = new Date();
      await careRequest.save();

      // Assign the nurse to the patient
      await User.findByIdAndUpdate(careRequest.patientId, {
        assignedNurse: nurseId,
      });

      const patient = await User.findById(careRequest.patientId).select("name email phone");

      return res.status(200).json({
        success: true,
        message: "Demande accept\u00e9e. Le patient est maintenant assign\u00e9.",
        patient,
      });
    } else {
      // Refuse the request
      careRequest.status = "refused";
      careRequest.respondedAt = new Date();
      await careRequest.save();

      return res.status(200).json({
        success: true,
        message: "Demande refus\u00e9e.",
      });
    }
  } catch (error) {
    console.error("Error responding to request:", error);
    res.status(500).json({
      success: false,
      message: "Erreur serveur.",
      error: error.message,
    });
  }
};
