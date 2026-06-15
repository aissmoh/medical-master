import { getIO } from "../socket.js";
import Message from "../models/messageModel.js";
import User from "../models/userModel.js";

// Envoyer un message
export const sendMessage = async (req, res) => {
  try {
    const { receiverId, content, type = "text", appointmentId, metadata } = req.body;
    const senderId = req.user.userId;

    if (!receiverId || !content) {
      return res.status(400).json({
        success: false,
        message: "Le destinataire et le contenu sont requis",
      });
    }

    // Vérifier que le destinataire existe
    const receiver = await User.findById(receiverId);
    if (!receiver) {
      return res.status(404).json({
        success: false,
        message: "Destinataire non trouvé",
      });
    }

    // Empêcher l'envoi à soi-même
    if (senderId === receiverId) {
      return res.status(400).json({
        success: false,
        message: "Vous ne pouvez pas vous envoyer un message à vous-même",
      });
    }

    const message = await Message.create({
      sender: senderId,
      receiver: receiverId,
      content: content.trim(),
      type,
      appointmentId: appointmentId || null,
      metadata: metadata || null,
    });

    // Récupérer le message avec les informations de l'expéditeur
    const populatedMessage = await Message.findById(message._id)
      .populate("sender", "name email isPatient")
      .populate("receiver", "name email isPatient");

    // Emit Socket.io for real-time delivery
    try {
      const io = getIO();
      io.to(`user:${receiverId}`).emit("new_message", populatedMessage);
      io.to(`user:${senderId}`).emit("message_sent", populatedMessage);
    } catch (_err) {
      console.warn("Socket emission error (non bloquante):", _err.message);
    }

    return res.status(201).json({
      success: true,
      message: "Message envoyé avec succès",
      data: populatedMessage,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'envoi du message",
      error: error.message,
    });
  }
};

// Récupérer les conversations de l'utilisateur
export const getConversations = async (req, res) => {
  try {
    const userId = req.user.userId;

    const conversations = await Message.getConversations(userId);

    return res.status(200).json({
      success: true,
      count: conversations.length,
      data: conversations,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des conversations",
      error: error.message,
    });
  }
};

// Récupérer les messages d'une conversation
export const getConversationMessages = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { contactId } = req.params;
    const { page = 1, limit = 20 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find({
      $or: [
        { sender: userId, receiver: contactId },
        { sender: contactId, receiver: userId },
      ],
    })
      .populate("sender", "name email isPatient")
      .populate("receiver", "name email isPatient")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Marquer les messages comme lus
    const unreadMessages = messages.filter(
      (msg) => msg.receiver._id.toString() === userId && !msg.isRead
    );

    if (unreadMessages.length > 0) {
      await Promise.all(unreadMessages.map((msg) => msg.markAsRead()));
    }

    const totalMessages = await Message.countDocuments({
      $or: [
        { sender: userId, receiver: contactId },
        { sender: contactId, receiver: userId },
      ],
    });

    return res.status(200).json({
      success: true,
      data: messages.reverse(), // Inverser pour avoir l'ordre chronologique
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalMessages,
        pages: Math.ceil(totalMessages / parseInt(limit)),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des messages",
      error: error.message,
    });
  }
};

// Récupérer tous les messages reçus
export const getReceivedMessages = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { isRead, page = 1, limit = 20 } = req.query;

    const filter = { receiver: userId };
    if (isRead !== undefined) {
      filter.isRead = isRead === "true";
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find(filter)
      .populate("sender", "name email isPatient")
      .populate("receiver", "name email isPatient")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments(filter);

    return res.status(200).json({
      success: true,
      count: messages.length,
      data: messages,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des messages",
      error: error.message,
    });
  }
};

// Récupérer tous les messages envoyés
export const getSentMessages = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find({ sender: userId })
      .populate("sender", "name email isPatient")
      .populate("receiver", "name email isPatient")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments({ sender: userId });

    return res.status(200).json({
      success: true,
      count: messages.length,
      data: messages,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des messages envoyés",
      error: error.message,
    });
  }
};

// Compter les messages non lus
export const getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.userId;

    const count = await Message.countUnread(userId);

    return res.status(200).json({
      success: true,
      count,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du comptage des messages non lus",
      error: error.message,
    });
  }
};

// Marquer un message comme lu
export const markAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user.userId;

    const message = await Message.findOne({
      _id: messageId,
      receiver: userId,
    });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: "Message non trouvé",
      });
    }

    await message.markAsRead();

    return res.status(200).json({
      success: true,
      message: "Message marqué comme lu",
      data: message,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du marquage du message",
      error: error.message,
    });
  }
};

// Marquer tous les messages comme lus
export const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { senderId } = req.body;

    const filter = { receiver: userId, isRead: false };
    if (senderId) {
      filter.sender = senderId;
    }

    const result = await Message.updateMany(filter, {
      isRead: true,
      readAt: new Date(),
    });

    return res.status(200).json({
      success: true,
      message: `${result.modifiedCount} message(s) marqué(s) comme lu(s)`,
      count: result.modifiedCount,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors du marquage des messages",
      error: error.message,
    });
  }
};

// Supprimer un message
export const deleteMessage = async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user.userId;

    const message = await Message.findOne({
      _id: messageId,
      $or: [{ sender: userId }, { receiver: userId }],
    });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: "Message non trouvé",
      });
    }

    await Message.findByIdAndDelete(messageId);

    return res.status(200).json({
      success: true,
      message: "Message supprimé avec succès",
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la suppression du message",
      error: error.message,
    });
  }
};

// Envoyer un message système (pour les notifications automatiques)
export const sendSystemMessage = async (req, res) => {
  try {
    const { receiverId, content, type, metadata } = req.body;

    // Cette fonction est réservée aux admins ou aux tâches automatisées
    // On peut vérifier si l'utilisateur est admin ou utiliser une clé API

    const message = await Message.create({
      sender: null, // Système
      receiver: receiverId,
      content: content.trim(),
      type: type || "system",
      metadata: metadata || null,
    });

    const populatedMessage = await Message.findById(message._id)
      .populate("receiver", "name email isPatient");

    return res.status(201).json({
      success: true,
      message: "Message système envoyé avec succès",
      data: populatedMessage,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'envoi du message système",
      error: error.message,
    });
  }
};
