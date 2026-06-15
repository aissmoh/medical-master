import express from "express";
import { authenticateToken, requirePatient, requireNurse } from "../middleware/auth.js";

import {
  createAppointment,
  getPatientAppointments,
  getNurseAppointments,
  getAvailableAppointments,
  acceptAppointment,
  rejectAppointment,
  cancelAppointment,
  completeAppointment,
  getAppointmentsCalendar,
  getAllAppointments,
} from "../controllers/appointmentController.js";

const router = express.Router();

// Middleware pour vérifier l'authentification
router.use(authenticateToken);

// Créer un rendez-vous (patient uniquement)
router.post("/", requirePatient, createAppointment);

// Voir les rendez-vous du patient
router.get("/patient", requirePatient, getPatientAppointments);

// Voir les rendez-vous de l'infirmier
router.get("/nurse", requireNurse, getNurseAppointments);

// 📋 Voir tous les rendez-vous (admin)
router.get("/all", getAllAppointments);

// 📋 Voir les rendez-vous disponibles (pour les infirmiers)
router.get("/available", requireNurse, getAvailableAppointments);

// 📅 Voir le calendrier des rendez-vous
router.get("/calendar", getAppointmentsCalendar);

// ✅ Accepter un rendez-vous (infirmier uniquement)
router.patch("/:appointmentId/accept", requireNurse, acceptAppointment);

// ❌ Refuser un rendez-vous (infirmier uniquement)
router.patch("/:appointmentId/reject", requireNurse, rejectAppointment);

// 🚫 Annuler un rendez-vous (patient uniquement)
router.patch("/:appointmentId/cancel", requirePatient, cancelAppointment);

// ✅ Compléter un rendez-vous (infirmier uniquement)
router.patch("/:appointmentId/complete", requireNurse, completeAppointment);

export default router;
