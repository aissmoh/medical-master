import mongoose from "mongoose";

const messageSchema = new mongoose.Schema(
  {
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'expéditeur est requis"],
    },
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Le destinataire est requis"],
    },
    content: {
      type: String,
      required: [true, "Le contenu du message est requis"],
      trim: true,
      maxlength: [2000, "Le message ne peut pas dépasser 2000 caractères"],
    },
    type: {
      type: String,
      enum: ["text", "appointment_reminder", "lab_results", "prescription", "system", "diet_advice"],
      default: "text",
    },
    isRead: {
      type: Boolean,
      default: false,
    },
    readAt: {
      type: Date,
      default: null,
    },
    appointmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Index pour améliorer les performances des requêtes
messageSchema.index({ receiver: 1, isRead: 1, createdAt: -1 });
messageSchema.index({ sender: 1, receiver: 1, createdAt: -1 });
messageSchema.index({ receiver: 1, createdAt: -1 });

// Middleware pour mettre à jour readAt lorsque isRead passe à true
messageSchema.pre("save", function() {
  if (this.isModified("isRead") && this.isRead && !this.readAt) {
    this.readAt = new Date();
  }
});

// Méthode pour marquer comme lu
messageSchema.methods.markAsRead = async function () {
  if (!this.isRead) {
    this.isRead = true;
    this.readAt = new Date();
    await this.save();
  }
  return this;
};

// Méthode statique pour compter les messages non lus
messageSchema.statics.countUnread = async function (userId) {
  return this.countDocuments({ receiver: userId, isRead: false });
};

// Méthode statique pour obtenir les conversations
messageSchema.statics.getConversations = async function (userId) {
  return this.aggregate([
    {
      $match: {
        $or: [
          { sender: new mongoose.Types.ObjectId(userId) },
          { receiver: new mongoose.Types.ObjectId(userId) },
        ],
      },
    },
    {
      $sort: { createdAt: -1 },
    },
    {
      $group: {
        _id: {
          $cond: {
            if: { $eq: ["$sender", new mongoose.Types.ObjectId(userId)] },
            then: "$receiver",
            else: "$sender",
          },
        },
        lastMessage: { $first: "$$ROOT" },
        unreadCount: {
          $sum: {
            $cond: [
              {
                $and: [
                  { $eq: ["$receiver", new mongoose.Types.ObjectId(userId)] },
                  { $eq: ["$isRead", false] },
                ],
              },
              1,
              0,
            ],
          },
        },
      },
    },
    {
      $lookup: {
        from: "users",
        localField: "_id",
        foreignField: "_id",
        as: "contact",
      },
    },
    {
      $unwind: "$contact",
    },
    {
      $project: {
        _id: 1,
        contact: {
          _id: 1,
          name: 1,
          email: 1,
          isPatient: 1,
        },
        lastMessage: 1,
        unreadCount: 1,
      },
    },
    {
      $sort: { "lastMessage.createdAt": -1 },
    },
  ]);
};

const Message = mongoose.model("Message", messageSchema);

export default Message;
