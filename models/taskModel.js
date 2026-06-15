import mongoose from "mongoose";

const taskSchema = new mongoose.Schema(
  {
    nurseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID de l'infirmier est requis"],
    },
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "L'ID du patient est requis"],
    },
    title: {
      type: String,
      required: [true, "Le titre de la tâche est requis"],
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: "",
    },
    type: {
      type: String,
      enum: ["medication", "control", "procedure", "other"],
      default: "other",
    },
    scheduledTime: {
      type: Date,
      required: [true, "L'heure prévue est requise"],
    },
    status: {
      type: String,
      enum: ["pending", "completed", "cancelled"],
      default: "pending",
    },
    completedAt: {
      type: Date,
      default: null,
    },
    completedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    notes: {
      type: String,
      default: "",
    },
    priority: {
      type: String,
      enum: ["low", "normal", "high"],
      default: "normal",
    },
  },
  {
    timestamps: true,
  }
);

// Index for faster queries
taskSchema.index({ nurseId: 1, status: 1, scheduledTime: 1 });
taskSchema.index({ patientId: 1, status: 1 });

const Task = mongoose.model("Task", taskSchema);

export default Task;
