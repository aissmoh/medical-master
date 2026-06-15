import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getMyTasks,
  getPatientTasks,
  createTask,
  completeTask,
  updateTask,
  deleteTask,
  getTodayStats,
} from "../controllers/taskController.js";

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// @route   GET /api/v1/tasks
// @desc    Get all tasks for logged in nurse (with optional filters)
router.get("/", getMyTasks);

// @route   GET /api/v1/tasks/today/stats
// @desc    Get today's tasks statistics
router.get("/today/stats", getTodayStats);

// @route   GET /api/v1/tasks/patient/:patientId
// @desc    Get tasks for a specific patient
router.get("/patient/:patientId", getPatientTasks);

// @route   POST /api/v1/tasks
// @desc    Create new task
router.post("/", createTask);

// @route   PUT /api/v1/tasks/:taskId
// @desc    Update task
router.put("/:taskId", updateTask);

// @route   PUT /api/v1/tasks/:taskId/complete
// @desc    Mark task as completed
router.put("/:taskId/complete", completeTask);

// @route   DELETE /api/v1/tasks/:taskId
// @desc    Delete task
router.delete("/:taskId", deleteTask);

export default router;
