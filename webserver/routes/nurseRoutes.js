import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getMyPatients,
  getPatientDetails,
  getActiveAlerts,
  acknowledgeAlert,
  resolveAlert,
  createSOSAlert,
  getAlertHistory,
  getPatientVitalsChart,
  getPendingRequests,
  respondToRequest,
} from "../controllers/nurseController.js";

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// ============ Patient Management Routes ============

// @route   GET /api/v1/nurse/my-patients
// @desc    Get all patients assigned to logged in nurse
router.get("/my-patients", getMyPatients);

// @route   GET /api/v1/nurse/patient/:patientId/details
// @desc    Get detailed information about a specific patient
router.get("/patient/:patientId/details", getPatientDetails);

// @route   GET /api/v1/nurse/patient/:patientId/vitals/chart
// @desc    Get patient vital signs chart data
router.get("/patient/:patientId/vitals/chart", getPatientVitalsChart);

// ============ Care Request Routes ============

// @route   GET /api/v1/nurse/pending-requests
// @desc    Get pending care requests from patients
router.get("/pending-requests", getPendingRequests);

// @route   PATCH /api/v1/nurse/respond-request/:requestId
// @desc    Accept or refuse a care request
router.patch("/respond-request/:requestId", respondToRequest);

// ============ Alert Management Routes ============

// @route   GET /api/v1/nurse/alerts
// @desc    Get active SOS alerts for nurse's patients
router.get("/alerts", getActiveAlerts);

// @route   GET /api/v1/nurse/alerts/history
// @desc    Get alert history
router.get("/alerts/history", getAlertHistory);

// @route   POST /api/v1/nurse/sos
// @desc    Create SOS alert
router.post("/sos", createSOSAlert);

// @route   PUT /api/v1/nurse/alerts/:alertId/acknowledge
// @desc    Acknowledge an alert
router.put("/alerts/:alertId/acknowledge", acknowledgeAlert);

// @route   PUT /api/v1/nurse/alerts/:alertId/resolve
// @desc    Resolve an alert
router.put("/alerts/:alertId/resolve", resolveAlert);

export default router;

