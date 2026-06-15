import express from "express";

import {
  login,
  signUp,
  verifySignUpOtp,
  logout,
} from "../controllers/authController.js";

const router = express.Router();

router.post("/signup", signUp);
router.post("/verify-signup-otp", verifySignUpOtp);
router.post("/login", login);
router.post("/logout", logout);

export default router;
