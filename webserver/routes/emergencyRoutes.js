import express from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  triggerEmergency,
  deleteEmergency,
  acceptEmergency,
  markInProgress,
  resolveEmergency,
  cancelEmergency,
  getPatientEmergencies,
  getNurseEmergencies,
  getActiveEmergencies,
  getEmergencyById,
} from "../controllers/emergencyController.js";

const router = express.Router();

// Middleware pour vérifier l'authentification
router.use(authenticateToken);

// 🚨 Déclencher une urgence (Patient)
router.post("/trigger", triggerEmergency);

// 📍 Récupérer les urgences actives (Infirmier)
router.get("/active", getActiveEmergencies);

// 📋 Récupérer mes urgences (Patient)
router.get("/patient", getPatientEmergencies);

// 📋 Récupérer mes urgences assignées (Infirmier)
router.get("/nurse", getNurseEmergencies);

// 📄 Récupérer les détails d'une urgence
router.get("/:emergencyId", getEmergencyById);

// ✅ Accepter une urgence (Infirmier)
router.patch("/:emergencyId/accept", acceptEmergency);

// 🚑 Marquer en cours (Infirmier)
router.patch("/:emergencyId/in-progress", markInProgress);

// ✓ Résoudre l'urgence (Infirmier)
router.patch("/:emergencyId/resolve", resolveEmergency);

// ❌ Annuler l'urgence (Patient)
router.patch("/:emergencyId/cancel", cancelEmergency);

export default router;

// Supprimer une urgence (Admin)
router.delete('/:emergencyId', deleteEmergency);
