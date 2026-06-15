import express from "express";
import { authenticateToken } from "../middleware/auth.js";

import {
  recordVitalSigns,
  getMyLatestVitalSigns,
  getMyVitalSignsHistory,
  getPatientVitalSigns,
  getPatientHistory,
  getMyAlerts,
  getPatientStats,
  getAllPatientsVitalSigns,
  deleteVitalSignsEntry,
  receiveArduinoData,
  // Endpoints séparés par type
  getMyTemperatureHistory,
  getMyOxygenHistory,
  getMyHeartRateHistory,
  getPatientTemperatureHistory,
  getPatientOxygenHistory,
  getPatientHeartRateHistory,
} from "../controllers/vitalSignsController.js";

const router = express.Router();

// 📡 Route pour Arduino (sans authentification - clé API requise)
router.post("/arduino", receiveArduinoData);

// Middleware pour vérifier l'authentification
router.use(authenticateToken);

// 📊 Routes pour les Patients
// Enregistrer de nouvelles données (Patient)
router.post("/record", recordVitalSigns);

// Obtenir mes dernières données (Patient)
router.get("/me/latest", getMyLatestVitalSigns);

// Obtenir mon historique (Patient)
router.get("/me/history", getMyVitalSignsHistory);

// 📋 Historique séparé par type (Patient)
router.get("/me/temperature", getMyTemperatureHistory);
router.get("/me/oxygen", getMyOxygenHistory);
router.get("/me/heartrate", getMyHeartRateHistory);

// 📊 Routes pour les Infirmiers
// Obtenir les données d'un patient spécifique
router.get("/patient/:patientId", getPatientVitalSigns);

// Obtenir l'historique d'un patient
router.get("/patient/:patientId/history", getPatientHistory);

// 📋 Historique séparé par type (Infirmier)
router.get("/patient/:patientId/temperature", getPatientTemperatureHistory);
router.get("/patient/:patientId/oxygen", getPatientOxygenHistory);
router.get("/patient/:patientId/heartrate", getPatientHeartRateHistory);

// Obtenir les statistiques d'un patient
router.get("/patient/:patientId/stats", getPatientStats);

// Obtenir toutes les données des patients (dashboard infirmier)
router.get("/all-patients", getAllPatientsVitalSigns);

// Obtenir mes alertes (pour l'infirmier)
router.get("/alerts", getMyAlerts);

// 🗑️ Suppression (Admin ou propriétaire)
router.delete("/:entryId", deleteVitalSignsEntry);

export default router;
