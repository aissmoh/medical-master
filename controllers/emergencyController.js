import { getIO } from "../socket.js";
import Emergency from "../models/emergencyModel.js";
import SOSAlert from "../models/sosAlertModel.js";
import User from "../models/userModel.js";

// Déclencher une urgence (SOS)
export const triggerEmergency = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { lat, lng, address, type, description, vitalSigns } = req.body;

    // Validation des coordonnées GPS
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({
        success: false,
        message: "Les coordonnées GPS (lat, lng) sont requises",
      });
    }

    // Vérifier que c'est bien un patient
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les patients peuvent déclencher une urgence",
      });
    }

    // Vérifier s'il y a déjà une urgence active pour ce patient
    const existingEmergency = await Emergency.findOne({
      patientId,
      status: { $in: ["pending", "accepted", "in_progress"] },
    });

    if (existingEmergency) {
      return res.status(409).json({
        success: false,
        message: "Vous avez déjà une urgence en cours",
        data: existingEmergency,
      });
    }

    // Créer l'urgence
    const emergency = await Emergency.create({
      patientId,
      location: {
        lat,
        lng,
        address: address || null,
      },
      type: type || "other",
      description: description || null,
      vitalSigns: vitalSigns || {},
      status: "pending",
    });

    // Récupérer les infirmiers disponibles
    const nearbyNurses = await emergency.findNearbyNurses(50);

    // TODO: Envoyer les notifications aux infirmiers
    // Cette partie sera implémentée avec Firebase Cloud Messaging
    const notificationsToSend = nearbyNurses.map(({ nurse }) => ({
      nurseId: nurse._id,
      channel: "push",
      sentAt: new Date(),
    }));

    emergency.notificationsSent = notificationsToSend;
    await emergency.save();

    // Récupérer l'urgence avec les données du patient
    const populatedEmergency = await Emergency.findById(emergency._id)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    // Emit Socket.io notification to all nurses
    try {
      const io = getIO();
      const payload = {
        type: "emergency:new",
        data: populatedEmergency,
        patientName: patient.name,
      };
      // Notify all nurses individually
      nearbyNurses.forEach(({ nurse }) => {
        io.to(`nurse:${nurse._id}`).emit("emergency:new", payload);
      });
      // Broadcast to all connected nurses
      io.emit("emergency:new", payload);
    } catch (_err) {
      console.warn("Socket emission error (non bloquante):", _err.message);
    }

    return res.status(201).json({
      success: true,
      message: "Urgence déclenchée avec succès",
      data: populatedEmergency,
      nearbyNursesCount: nearbyNurses.length,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du déclenchement de l'urgence",
      error: error.message,
    });
  }
};

// Accepter une urgence (pour les infirmiers)
export const acceptEmergency = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { emergencyId } = req.params;

    // Vérifier que c'est bien un infirmier
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les soignants peuvent accepter une urgence",
      });
    }

    const emergency = await Emergency.findById(emergencyId);
    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: "Urgence non trouvée",
      });
    }

    if (emergency.status !== "pending") {
      return res.status(409).json({
        success: false,
        message: "Cette urgence a déjà été prise en charge",
        data: emergency,
      });
    }

    await emergency.acceptEmergency(nurseId);

    const populatedEmergency = await Emergency.findById(emergencyId)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    return res.status(200).json({
      success: true,
      message: "Urgence acceptée avec succès",
      data: populatedEmergency,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'acceptation de l'urgence",
      error: error.message,
    });
  }
};

// Marquer l'urgence en cours (l'infirmier est sur place)
export const markInProgress = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { emergencyId } = req.params;

    const emergency = await Emergency.findById(emergencyId);
    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: "Urgence non trouvée",
      });
    }

    // Vérifier que c'est l'infirmier assigné
    if (emergency.assignedNurseId?.toString() !== nurseId) {
      return res.status(403).json({
        success: false,
        message: "Vous n'êtes pas assigné à cette urgence",
      });
    }

    await emergency.markInProgress();

    const populatedEmergency = await Emergency.findById(emergencyId)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    return res.status(200).json({
      success: true,
      message: "Intervention en cours",
      data: populatedEmergency,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du changement de statut",
      error: error.message,
    });
  }
};

// Résoudre l'urgence
export const resolveEmergency = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { emergencyId } = req.params;
    const { notes } = req.body;

    const emergency = await Emergency.findById(emergencyId);
    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: "Urgence non trouvée",
      });
    }

    // Vérifier que c'est l'infirmier assigné
    if (emergency.assignedNurseId?.toString() !== nurseId) {
      return res.status(403).json({
        success: false,
        message: "Vous n'êtes pas assigné à cette urgence",
      });
    }

    await emergency.resolve(notes);

    const populatedEmergency = await Emergency.findById(emergencyId)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    return res.status(200).json({
      success: true,
      message: "Urgence résolue avec succès",
      data: populatedEmergency,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la résolution de l'urgence",
      error: error.message,
    });
  }
};

// Annuler l'urgence (par le patient)
export const cancelEmergency = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { emergencyId } = req.params;
    const { reason } = req.body;

    const emergency = await Emergency.findById(emergencyId);
    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: "Urgence non trouvée",
      });
    }

    // Vérifier que c'est le patient qui a créé l'urgence
    if (emergency.patientId.toString() !== patientId) {
      return res.status(403).json({
        success: false,
        message: "Vous ne pouvez pas annuler cette urgence",
      });
    }

    if (emergency.status === "resolved") {
      return res.status(400).json({
        success: false,
        message: "Impossible d'annuler une urgence déjà résolue",
      });
    }

    await emergency.cancel(reason);

    return res.status(200).json({
      success: true,
      message: "Urgence annulée",
      data: emergency,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'annulation",
      error: error.message,
    });
  }
};

// Récupérer les urgences du patient
export const getPatientEmergencies = async (req, res) => {
  try {
    const patientId = req.user.userId;

    const emergencies = await Emergency.getPatientEmergencies(patientId);

    return res.status(200).json({
      success: true,
      count: emergencies.length,
      data: emergencies,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des urgences",
      error: error.message,
    });
  }
};

// Récupérer les urgences assignées à un infirmier
export const getNurseEmergencies = async (req, res) => {
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

    const emergencies = await Emergency.getNurseEmergencies(nurseId);

    return res.status(200).json({
      success: true,
      count: emergencies.length,
      data: emergencies,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des urgences",
      error: error.message,
    });
  }
};

// Récupérer toutes les urgences actives (pour les infirmiers)
export const getActiveEmergencies = async (req, res) => {
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

    // Mettre à jour la position de l'infirmier si fournie
    const { lat, lng } = req.query;
    if (lat && lng) {
      nurse.location = {
        lat: parseFloat(lat),
        lng: parseFloat(lng),
        lastUpdated: new Date(),
      };
      await nurse.save();
    }

    const emergencies = await Emergency.getActiveEmergencies();

    // Also get active SOS alerts from sosalerts collection
    const sosAlerts = await SOSAlert.find({
      status: { $in: ["active", "acknowledged"] }
    }).populate("patientId", "name email phone isPatient")
      .sort({ createdAt: -1 });

    const normalizedSOS = sosAlerts.map((alert) => ({
      _id: alert._id,
      patientId: alert.patientId,
      type: alert.type || "emergency",
      description: alert.message,
      status: alert.status === "active" ? "pending" : "accepted",
      location: { lat: alert.location?.coordinates?.[0] || 0, lng: alert.location?.coordinates?.[1] || 0 },
      createdAt: alert.createdAt,
      source: "sos",
    }));

    const allEmergencies = [...normalizedSOS, ...emergencies];

    // Calculer la distance pour chaque urgence
    const emergenciesWithDistance = allEmergencies.map((emergency) => ({
      ...emergency,
      distance: 0,
    }));

    // Trier par distance
    emergenciesWithDistance.sort((a, b) => a.distance - b.distance);

    return res.status(200).json({
      success: true,
      count: emergenciesWithDistance.length,
      data: emergenciesWithDistance,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des urgences",
      error: error.message,
    });
  }
};

// Récupérer les détails d'une urgence
export const getEmergencyById = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { emergencyId } = req.params;

    const emergency = await Emergency.findById(emergencyId)
      .populate("patientId", "name email phone isPatient")
      .populate("assignedNurseId", "name email phone");

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: "Urgence non trouvée",
      });
    }

    // Vérifier les permissions
    const isPatient = emergency.patientId._id.toString() === userId;
    const isAssignedNurse =
      emergency.assignedNurseId?._id.toString() === userId;

    if (!isPatient && !isAssignedNurse) {
      // Pour les autres infirmiers, vérifier s'ils sont dans la liste des notifications
      const isNotifiedNurse = emergency.notificationsSent.some(
        (n) => n.nurseId.toString() === userId
      );

      if (!isNotifiedNurse) {
        return res.status(403).json({
          success: false,
          message: "Accès non autorisé",
        });
      }
    }

    return res.status(200).json({
      success: true,
      data: emergency,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération de l'urgence",
      error: error.message,
    });
  }
};

// Supprimer une urgence (Admin)
export const deleteEmergency = async (req, res) => {
  try {
    const { emergencyId } = req.params;
    const userId = req.user.userId;
    const user = await User.findById(userId);
    if (!user || user.isPatient) {
      return res.status(403).json({ success: false, message: "Accès réservé aux administrateurs" });
    }

    // Try deleting from emergencies collection first
    let deleted = await Emergency.findByIdAndDelete(emergencyId);
    if (deleted) {
      return res.status(200).json({ success: true, message: "Urgence supprimée" });
    }

    // Try deleting from sosalerts collection
    deleted = await SOSAlert.findByIdAndDelete(emergencyId);
    if (deleted) {
      return res.status(200).json({ success: true, message: "Alerte SOS supprimée" });
    }

    return res.status(404).json({ success: false, message: "Urgence non trouvée" });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur serveur", error: error.message });
  }
};
