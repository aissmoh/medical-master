import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  createEmergencyAlert,
  getMyAlerts,
  cancelMyAlert,
  getMyNurse,
  requestNurse,
  getMyRequests,
  alertMyNurse,
  updateMyLocation,
  getAvailableNurses,
} from "../controllers/patientController.js";

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// @route   POST /api/v1/patient/sos
// @desc    Create emergency SOS alert
router.post("/sos", createEmergencyAlert);

// @route   GET /api/v1/patient/alerts
// @desc    Get patient's alert history
router.get("/alerts", getMyAlerts);

// @route   PUT /api/v1/patient/alerts/:alertId/cancel
// @desc    Cancel patient's alert
router.put("/alerts/:alertId/cancel", cancelMyAlert);

// @route   GET /api/v1/patient/my-nurse
// @desc    Get patient's assigned nurse
router.get("/my-nurse", getMyNurse);

// @route   POST /api/v1/patient/request-nurse
// @desc    Send a care request to a garde malade
router.post("/request-nurse", requestNurse);

// @route   GET /api/v1/patient/my-requests
// @desc    Get patient's care requests
router.get("/my-requests", getMyRequests);

// @route   POST /api/v1/patient/alert-my-nurse
// @desc    Send alert to assigned nurse with GPS location
router.post("/alert-my-nurse", alertMyNurse);

// @route   PUT /api/v1/patient/location
// @desc    Update patient's current GPS location
router.put("/location", updateMyLocation);

// @route   GET /api/v1/patient/users/nurses
// @desc    Get all available nurses/caregivers
router.get("/users/nurses", getAvailableNurses);

export default router;

