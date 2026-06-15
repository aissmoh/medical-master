import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import {
  getUserSettings,
  updateProfile,
  getSupportedLanguages,
} from "../controllers/settingsController.js";

const router = express.Router();

// Public route - get supported languages
router.get("/languages", getSupportedLanguages);

// Protected routes
router.use(authenticateToken);

router.get("/", getUserSettings);
router.put("/profile", updateProfile);

export default router;
