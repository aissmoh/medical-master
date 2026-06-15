import express from "express";
import { authenticateToken } from "../middleware/auth.js";
import upload from "../middleware/upload.js";

import {
  getUsers,
  getNurses,
  getUserById,
  searchUsers,
  getMyProfile,
  updateMyProfile,
  updateProfilePhoto,
  createUser,
  updateUser,
  deleteUser,
} from "../controllers/userController.js";

const router = express.Router();

// Middleware pour vérifier l'authentification
router.use(authenticateToken);

// Récupérer tous les utilisateurs
router.get("/", getUsers);

// Rechercher des utilisateurs
router.get("/search", searchUsers);

// Récupérer le profil de l'utilisateur connecté
router.get("/me", getMyProfile);

// Mettre à jour le profil
router.put("/profile", updateMyProfile);

// Uploader une photo de profil
router.put("/profile/photo", upload.single("photo"), updateProfilePhoto);

// Récupérer les infirmiers/soignants
router.get("/nurses", getNurses);

// ✅ Créer un utilisateur (admin, sans OTP)
router.post("/create", createUser);

// ✅ Modifier un utilisateur (admin)
router.put("/:userId", updateUser);

// ✅ Supprimer un utilisateur (admin)
router.delete("/:userId", deleteUser);

// Récupérer un utilisateur par ID
router.get("/:userId", getUserById);

export default router;
