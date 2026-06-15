import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  recordTemperature, getMyTemperature, getPatientTemperature,
  recordOxygen, getMyOxygen, getPatientOxygen,
  recordHeartRate, getMyHeartRate, getPatientHeartRate,
} from "../controllers/vitalSignsTablesController.js";

const router = express.Router();

router.use(authenticateToken);

// ===== TEMPERATURE =====
router.post("/temperature", recordTemperature);
router.get("/temperature/me", getMyTemperature);
router.get("/temperature/patient/:patientId", getPatientTemperature);

// ===== OXYGEN =====
router.post("/oxygen", recordOxygen);
router.get("/oxygen/me", getMyOxygen);
router.get("/oxygen/patient/:patientId", getPatientOxygen);

// ===== HEART RATE =====
router.post("/heartrate", recordHeartRate);
router.get("/heartrate/me", getMyHeartRate);
router.get("/heartrate/patient/:patientId", getPatientHeartRate);

export default router;
