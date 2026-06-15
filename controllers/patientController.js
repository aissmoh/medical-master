import { getIO } from "../socket.js";
import SOSAlert from "../models/sosAlertModel.js";
import User from "../models/userModel.js";
import CareRequest from "../models/careRequestModel.js";
import { getMessage } from "../services/languageService.js";

// @desc    Create SOS alert from patient emergency button
// @route   POST /api/v1/patient/sos
// @access  Private (Patient only)
export const createEmergencyAlert = async (req, res) => {
  try {
    const patientId = req.user._id;
    const { message, type = "emergency", location } = req.body;
    const lang = req.user.preferredLanguage || "fr";

    // Verify user is patient
    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    // Get patient details to find assigned nurse
    const patient = await User.findById(patientId);
    if (!patient) {
      return res.status(404).json({
        success: false,
        message: getMessage("patientNotFound", lang),
      });
    }

    // Determine alert type and priority
    let alertPriority = "high";
    let alertType = type;
    
    if (message && message.toLowerCase().includes("chute")) {
      alertType = "fall";
      alertPriority = "critical";
    } else if (message && message.toLowerCase().includes("douleur")) {
      alertType = "pain";
      alertPriority = "high";
    } else if (message && message.toLowerCase().includes("médicament")) {
      alertType = "medication";
      alertPriority = "normal";
    }

    // Create SOS alert
    const sosAlert = await SOSAlert.create({
      patientId: patientId,
      message: message || "Alerte d'urgence déclenchée par le patient",
      type: alertType,
      priority: alertPriority,
      status: "active",
      location: location || patient.roomInfo,
      metadata: {
        triggeredBy: "patient_button",
        deviceInfo: req.headers["user-agent"],
        ipAddress: req.ip,
      },
    });

    // Populate patient info for response
    await sosAlert.populate("patientId", "name roomInfo assignedNurse");

    // TODO: Send real-time notification to nurse via WebSocket
    // notifyNurse(patient.assignedNurse, sosAlert);

    // TODO: Send push notification
    // sendPushNotification(patient.assignedNurse, {
    //   title: "🚨 Alerte SOS",
    //   body: `${patient.name} a déclenché une alerte d'urgence`,
    // });

    // Emit Socket.io notification to assigned nurse
    try {
      const io = getIO();
      const payload = {
        type: "sos:new",
        alert: sosAlert,
        patientName: patient.name,
      };
      if (patient.assignedNurse) {
        io.to(`nurse:${patient.assignedNurse}`).emit("sos:new", payload);
      }
      io.emit("sos:new", payload);
    } catch (_err) {
      console.warn("Socket emission error (non bloquante):", _err.message);
    }

    res.status(201).json({
      success: true,
      message: getMessage("sosAlertCreated", lang),
      alert: sosAlert,
    });
  } catch (error) {
    console.error("Error creating emergency alert:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
      error: error.message,
    });
  }
};

// @desc    Get patient's alert history
// @route   GET /api/v1/patient/alerts
// @access  Private (Patient only)
export const getMyAlerts = async (req, res) => {
  try {
    const patientId = req.user._id;
    const lang = req.user.preferredLanguage || "fr";

    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    const alerts = await SOSAlert.find({ patientId })
      .populate("acknowledgedBy", "name")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: alerts.length,
      alerts,
    });
  } catch (error) {
    console.error("Error getting patient alerts:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
    });
  }
};

// @desc    Cancel patient's own alert (if not yet acknowledged)
// @route   PUT /api/v1/patient/alerts/:alertId/cancel
// @access  Private (Patient only)
export const cancelMyAlert = async (req, res) => {
  try {
    const { alertId } = req.params;
    const patientId = req.user._id;
    const lang = req.user.preferredLanguage || "fr";

    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    const alert = await SOSAlert.findOneAndUpdate(
      {
        _id: alertId,
        patientId: patientId,
        status: "active", // Can only cancel active alerts
      },
      {
        status: "cancelled",
        cancelledAt: new Date(),
        cancelledBy: patientId,
      },
      { new: true }
    );

    if (!alert) {
      return res.status(404).json({
        success: false,
        message: "Alerte non trouvée ou déjà traitée",
      });
    }

    res.status(200).json({
      success: true,
      message: "Alerte annulée",
      alert,
    });
  } catch (error) {
    console.error("Error cancelling alert:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
    });
  }
};

// @desc    Get patient's assigned nurse info
// @route   GET /api/v1/patient/my-nurse
// @access  Private (Patient only)
export const getMyNurse = async (req, res) => {
  try {
    const patientId = req.user._id;
    const lang = req.user.preferredLanguage || "fr";

    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    const patient = await User.findById(patientId).populate(
      "assignedNurse",
      "name email phone"
    );

    if (!patient || !patient.assignedNurse) {
      return res.status(404).json({
        success: false,
        message: "Aucun infirmier assigné",
      });
    }

    res.status(200).json({
      success: true,
      nurse: patient.assignedNurse,
    });
  } catch (error) {
    console.error("Error getting nurse info:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
    });
  }
};

// @desc    Send a care request to a garde malade (by email or phone)
// @route   POST /api/v1/patient/request-nurse
// @access  Private (Patient only)
export const requestNurse = async (req, res) => {
  try {
    const patientId = req.user._id;
    const {
      email,
      phone,
      reason,
      urgency,
      symptoms,
      lat,
      lng,
      address,
      preferredContactTime,
      patientNotes,
    } = req.body;

    if (!email && !phone) {
      return res.status(400).json({
        success: false,
        message: "Veuillez fournir l'email ou le numéro de téléphone du garde malade.",
      });
    }

    // Verify the current user is a patient
    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès réservé aux patients.",
      });
    }

    // Check if patient already has an assigned nurse
    if (req.user.assignedNurse) {
      return res.status(400).json({
        success: false,
        message: "Vous avez déjà un garde malade assigné.",
      });
    }

    // Search for the nurse by email or phone
    const searchQuery = email
      ? { email: email.trim().toLowerCase() }
      : { phone: phone.trim() };

    const nurse = await User.findOne(searchQuery);

    if (!nurse) {
      return res.status(404).json({
        success: false,
        message: "Aucun utilisateur trouvé avec ces informations.",
      });
    }

    if (!nurse.isVerified) {
      return res.status(400).json({
        success: false,
        message: "Ce garde malade n'a pas encore vérifié son compte.",
      });
    }

    if (nurse.isPatient) {
      return res.status(400).json({
        success: false,
        message: "L'utilisateur trouvé n'est pas un garde malade.",
      });
    }

    // Check if a pending request already exists
    const existingRequest = await CareRequest.findOne({
      patientId,
      status: "pending",
    });

    if (existingRequest) {
      return res.status(400).json({
        success: false,
        message: "Vous avez déjà une demande en attente.",
      });
    }

    // Create a pending care request with all enriched fields
    const careRequest = await CareRequest.create({
      patientId,
      nurseId: nurse._id,
      status: "pending",
      reason: reason || null,
      urgency: urgency || "medium",
      symptoms: symptoms || [],
      location:
        lat != null && lng != null
          ? { lat, lng, address: address || null }
          : undefined,
      preferredContactTime: preferredContactTime || null,
      patientNotes: patientNotes || null,
    });

    // Update patient's User.location with latest coordinates
    if (lat != null && lng != null) {
      await User.findByIdAndUpdate(patientId, {
        "location.lat": lat,
        "location.lng": lng,
        "location.address": address || null,
        "location.lastUpdated": new Date(),
      });
    }

    res.status(201).json({
      success: true,
      message: "Demande envoyée au garde malade avec succès.",
      request: {
        _id: careRequest._id,
        nurseName: nurse.name,
        nurseEmail: nurse.email,
        status: careRequest.status,
        createdAt: careRequest.createdAt,
      },
    });
  } catch (error) {
    console.error("Error requesting nurse:", error);
    res.status(500).json({
      success: false,
      message: "Erreur serveur lors de l'envoi de la demande.",
      error: error.message,
    });
  }
};

// @desc    Get my pending care requests (as patient)
// @route   GET /api/v1/patient/my-requests
// @access  Private (Patient only)
export const getMyRequests = async (req, res) => {
  try {
    const patientId = req.user._id;

    const requests = await CareRequest.find({ patientId })
      .populate("nurseId", "name email phone")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: requests.length,
      requests,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur serveur.",
      error: error.message,
    });
  }
};

// @desc    Send alert to assigned nurse with GPS location
// @route   POST /api/v1/patient/alert-my-nurse
// @access  Private (Patient only)
export const alertMyNurse = async (req, res) => {
  try {
    const patientId = req.user._id;
    const { lat, lng, message } = req.body;
    const lang = req.user.preferredLanguage || "fr";

    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    if (lat == null || lng == null) {
      return res.status(400).json({
        success: false,
        message: "Les coordonnées GPS (lat, lng) sont requises",
      });
    }

    // Get patient with assigned nurse
    const patient = await User.findById(patientId).populate(
      "assignedNurse",
      "name email phone"
    );

    if (!patient || !patient.assignedNurse) {
      return res.status(400).json({
        success: false,
        message: "Aucun garde malade assigné à votre compte",
      });
    }

    // Create an SOS alert with GPS location
    const alert = await SOSAlert.create({
      patientId,
      message: message || "🚨 Alerte envoyée à mon garde malade",
      type: "direct_alert",
      status: "active",
      location: {
        type: "Point",
        coordinates: [lng, lat], // GeoJSON: [longitude, latitude]
      },
    });

    await alert.populate("patientId", "name");

    // Update patient's User.location with latest GPS coordinates
    await User.findByIdAndUpdate(patientId, {
      "location.lat": lat,
      "location.lng": lng,
      "location.lastUpdated": new Date(),
    });

    // TODO: Send real-time notification to nurse via WebSocket
    // TODO: Send push notification to nurse

    res.status(201).json({
      success: true,
      message: "Alerte envoyée à votre garde malade avec votre position",
      data: {
        alert,
        nurse: {
          name: patient.assignedNurse.name,
          email: patient.assignedNurse.email,
          phone: patient.assignedNurse.phone,
        },
      },
    });
  } catch (error) {
    console.error("Error in alertMyNurse:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
      error: error.message,
    });
  }
};

// @desc    Update patient's current GPS location independently
// @route   PUT /api/v1/patient/location
// @access  Private (Patient only)
export const updateMyLocation = async (req, res) => {
  try {
    const patientId = req.user._id;
    const { lat, lng, address } = req.body;
    const lang = req.user.preferredLanguage || "fr";

    if (!req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    if (lat == null || lng == null) {
      return res.status(400).json({
        success: false,
        message: "Les coordonnées GPS (lat, lng) sont requises",
      });
    }

    await User.findByIdAndUpdate(patientId, {
      "location.lat": lat,
      "location.lng": lng,
      "location.address": address || null,
      "location.lastUpdated": new Date(),
    });

    res.status(200).json({
      success: true,
      message: "Position mise à jour avec succès",
    });
  } catch (error) {
    console.error("Error updating location:", error);
    res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la mise à jour de la position",
      error: error.message,
    });
  }
};

// @desc    Get all available nurses/caregivers
// @route   GET /api/v1/patient/users/nurses
// @access  Private (Patient only)
export const getAvailableNurses = async (req, res) => {
  try {
    const lang = req.user?.preferredLanguage || "fr";

    // Load user from database to get role
    const user = await User.findById(req.user.userId);
    
    if (!user || user.role !== "patient") {
      return res.status(403).json({
        success: false,
        message: getMessage("accessDenied", lang),
      });
    }

    // Get all users with role nurse or caregiver
    const nurses = await User.find({
      role: { $in: ["nurse", "caregiver"] },
      isAvailable: true,
    }).select("name email phone specialty experience rating");

    res.status(200).json({
      success: true,
      count: nurses.length,
      nurses,
    });
  } catch (error) {
    console.error("Error getting available nurses:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", req.user?.preferredLanguage || "fr"),
      error: error.message,
    });
  }
};
