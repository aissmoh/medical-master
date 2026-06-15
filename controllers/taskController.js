import Task from "../models/taskModel.js";
import User from "../models/userModel.js";

// @desc    Get all tasks for logged in nurse
// @route   GET /api/v1/tasks
// @access  Private (Nurse only)
export const getMyTasks = async (req, res) => {
  try {
    // Verify user is nurse
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé. Seuls les infirmiers peuvent voir les tâches.",
      });
    }

    const { status = "pending", date } = req.query;

    // Build query
    let query = { nurseId: req.user._id };

    if (status !== "all") {
      query.status = status;
    }

    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      query.scheduledTime = { $gte: startOfDay, $lte: endOfDay };
    }

    // Get tasks with patient info
    const tasks = await Task.find(query)
      .populate("patientId", "name roomInfo age gender profileImage")
      .sort({ scheduledTime: 1 });

    // Group by status for easier frontend handling
    const groupedTasks = {
      pending: tasks.filter((t) => t.status === "pending"),
      completed: tasks.filter((t) => t.status === "completed"),
      cancelled: tasks.filter((t) => t.status === "cancelled"),
    };

    res.status(200).json({
      success: true,
      count: tasks.length,
      tasks: groupedTasks,
    });
  } catch (error) {
    console.error("Error in getMyTasks:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des tâches",
      error: error.message,
    });
  }
};

// @desc    Get tasks for a specific patient
// @route   GET /api/v1/tasks/patient/:patientId
// @access  Private (Nurse only)
export const getPatientTasks = async (req, res) => {
  try {
    const { patientId } = req.params;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    // Verify patient is assigned to this nurse
    const patient = await User.findOne({
      _id: patientId,
      assignedNurse: req.user._id,
      isPatient: true,
    });

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé ou non assigné",
      });
    }

    const tasks = await Task.find({
      patientId: patientId,
      nurseId: req.user._id,
    })
      .populate("patientId", "name roomInfo")
      .sort({ scheduledTime: -1 });

    res.status(200).json({
      success: true,
      count: tasks.length,
      tasks,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Create new task
// @route   POST /api/v1/tasks
// @access  Private (Nurse only)
export const createTask = async (req, res) => {
  try {
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const { patientId, title, description, type, scheduledTime, priority } = req.body;

    // Verify patient is assigned to this nurse
    const patient = await User.findOne({
      _id: patientId,
      assignedNurse: req.user._id,
      isPatient: true,
    });

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: "Patient non trouvé ou non assigné",
      });
    }

    const task = await Task.create({
      nurseId: req.user._id,
      patientId,
      title,
      description,
      type,
      scheduledTime: new Date(scheduledTime),
      priority: priority || "normal",
      status: "pending",
    });

    const populatedTask = await Task.findById(task._id).populate(
      "patientId",
      "name roomInfo age gender"
    );

    res.status(201).json({
      success: true,
      message: "Tâche créée avec succès",
      task: populatedTask,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur lors de la création de la tâche",
      error: error.message,
    });
  }
};

// @desc    Mark task as completed
// @route   PUT /api/v1/tasks/:taskId/complete
// @access  Private (Nurse only)
export const completeTask = async (req, res) => {
  try {
    const { taskId } = req.params;
    const { notes } = req.body;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const task = await Task.findOneAndUpdate(
      {
        _id: taskId,
        nurseId: req.user._id,
        status: "pending",
      },
      {
        status: "completed",
        completedAt: new Date(),
        completedBy: req.user._id,
        notes: notes || "",
      },
      { new: true }
    ).populate("patientId", "name roomInfo");

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Tâche non trouvée ou déjà complétée",
      });
    }

    res.status(200).json({
      success: true,
      message: "Tâche marquée comme complétée",
      task,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Update task
// @route   PUT /api/v1/tasks/:taskId
// @access  Private (Nurse only)
export const updateTask = async (req, res) => {
  try {
    const { taskId } = req.params;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const updates = req.body;

    // Prevent updating completed tasks
    const existingTask = await Task.findOne({
      _id: taskId,
      nurseId: req.user._id,
    });

    if (!existingTask) {
      return res.status(404).json({
        success: false,
        message: "Tâche non trouvée",
      });
    }

    if (existingTask.status === "completed") {
      return res.status(400).json({
        success: false,
        message: "Impossible de modifier une tâche complétée",
      });
    }

    const task = await Task.findByIdAndUpdate(taskId, updates, {
      new: true,
      runValidators: true,
    }).populate("patientId", "name roomInfo");

    res.status(200).json({
      success: true,
      message: "Tâche mise à jour",
      task,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Delete task
// @route   DELETE /api/v1/tasks/:taskId
// @access  Private (Nurse only)
export const deleteTask = async (req, res) => {
  try {
    const { taskId } = req.params;

    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const task = await Task.findOneAndDelete({
      _id: taskId,
      nurseId: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: "Tâche non trouvée",
      });
    }

    res.status(200).json({
      success: true,
      message: "Tâche supprimée",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};

// @desc    Get today's tasks count
// @route   GET /api/v1/tasks/today/stats
// @access  Private (Nurse only)
export const getTodayStats = async (req, res) => {
  try {
    if (req.user.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès refusé.",
      });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const stats = await Task.aggregate([
      {
        $match: {
          nurseId: req.user._id,
          scheduledTime: { $gte: today, $lt: tomorrow },
        },
      },
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    const result = {
      total: 0,
      pending: 0,
      completed: 0,
      cancelled: 0,
    };

    stats.forEach((stat) => {
      result[stat._id] = stat.count;
      result.total += stat.count;
    });

    res.status(200).json({
      success: true,
      stats: result,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur",
      error: error.message,
    });
  }
};
