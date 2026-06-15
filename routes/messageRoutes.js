import express from "express";
import { authenticateToken, requirePatient } from "../middleware/auth.js";

import {
  sendMessage,
  getConversations,
  getConversationMessages,
  getReceivedMessages,
  getSentMessages,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteMessage,
  sendSystemMessage,
} from "../controllers/messageController.js";

const router = express.Router();

// Middleware pour vérifier l'authentification
router.use(authenticateToken);

// Envoyer un message
router.post("/", sendMessage);

// Récupérer les conversations
router.get("/conversations", getConversations);

// Récupérer les messages d'une conversation spécifique
router.get("/conversation/:contactId", getConversationMessages);

// Récupérer les messages reçus
router.get("/received", getReceivedMessages);

// Récupérer les messages envoyés
router.get("/sent", getSentMessages);

// Compter les messages non lus
router.get("/unread/count", getUnreadCount);

// Marquer un message comme lu
router.patch("/:messageId/read", markAsRead);

// Marquer tous les messages comme lus
router.patch("/read-all", markAllAsRead);

// Supprimer un message
router.delete("/:messageId", deleteMessage);

// Envoyer un message système (admin uniquement)
router.post("/system", sendSystemMessage);

export default router;
