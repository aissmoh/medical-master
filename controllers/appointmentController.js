import { getIO } from "../socket.js";
import Appointment from "../models/appointmentModel.js";
import User from "../models/userModel.js";
import { sendAppointmentEmail } from "../config/mail.js";

// 📅 إنشاء موعد جديد (المريض يطلب)
export const createAppointment = async (req, res) => {
  try {
    const { dateTime, duration, reason, notes, location } = req.body;
    const patientId = req.user.userId;

    // التحقق من أن المستخدم مريض
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les patients peuvent créer des rendez-vous",
      });
    }

    // التحقق من أن التاريخ في المستقبل
    const appointmentDate = new Date(dateTime);
    if (appointmentDate <= new Date()) {
      return res.status(400).json({
        success: false,
        message: "La date du rendez-vous doit être dans le futur",
      });
    }

    // التحقق من عدم وجود موعد في نفس الوقت
    const existingAppointment = await Appointment.findOne({
      patientId,
      dateTime: {
        $gte: new Date(appointmentDate.getTime() - 30 * 60 * 1000), // 30 دقيقة قبل
        $lte: new Date(appointmentDate.getTime() + parseInt(duration) * 60 * 1000), // بعد انتهاء الموعد
      },
      status: { $in: ["pending", "accepted"] },
    });

    if (existingAppointment) {
      return res.status(409).json({
        success: false,
        message: "Vous avez déjà un rendez-vous à cette période",
      });
    }

    // Check appointment limit (optional - can be configured)
    const MAX_APPOINTMENTS_PER_PATIENT = parseInt(process.env.MAX_APPOINTMENTS_PER_PATIENT || '999');
    
    if (MAX_APPOINTMENTS_PER_PATIENT > 0) {
      const activeAppointmentsCount = await Appointment.countDocuments({
        patientId,
        status: { $in: ["pending", "accepted"] }
      });
      
      if (activeAppointmentsCount >= MAX_APPOINTMENTS_PER_PATIENT) {
        return res.status(429).json({
          success: false,
          message: `Vous avez atteint la limite maximale de ${MAX_APPOINTMENTS_PER_PATIENT} rendez-vous actifs`
        });
      }
    }

    const appointment = await Appointment.create({
      patientId,
      dateTime,
      duration,
      reason,
      notes,
      location,
    });

    // Send notification to available nurses (can be improved later)
    try {
      const availableNurses = await User.find({ 
        isPatient: false, 
        isVerified: true 
      }).select('email name');

      for (const nurse of availableNurses) {
        try {
          await sendAppointmentEmail({
            to: nurse.email,
            nurseName: nurse.name,
            patientName: patient.name,
            appointmentDate,
            reason,
          });
        } catch (emailError) {
          console.log("Erreur envoi email infirmier:", emailError.message);
        }
      }
    } catch (nursesError) {
      console.log("Erreur finding nurses:", nursesError.message);
    }

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patientId", "name email")
      .populate("nurseId", "name email");

    // Emit Socket.io notification to nurses
    try {
      const io = getIO();
      io.emit("appointment:new", { type: "appointment:new", data: populatedAppointment });
    } catch (_err) {
      console.warn("Socket emission error (non bloquante):", _err.message);
    }

    return res.status(201).json({
      success: true,
      message: "Rendez-vous créé avec succès",
      appointment: populatedAppointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la création du rendez-vous",
      error: error.message,
    });
  }
};

// 📋 عرض مواعيد المريض
export const getPatientAppointments = async (req, res) => {
  try {
    const patientId = req.user.userId;
    const { status, page = 1, limit = 10 } = req.query;

    // التحقق من أن المستخدم مريض
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès non autorisé",
      });
    }

    const filter = { patientId };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter)
      .populate("nurseId", "name email")
      .sort({ dateTime: 1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Appointment.countDocuments(filter);

    return res.status(200).json({
      success: true,
      appointments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la récupération des rendez-vous",
      error: error.message,
    });
  }
};

// 📋 عرض طلبات المواعيد (للممرضين)
export const getNurseAppointments = async (req, res) => {
  try {
    const nurseId = req.user.userId;
    const { status, page = 1, limit = 10 } = req.query;

    // التحقق من أن المستخدم ممرض
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès non autorisé",
      });
    }

    const filter = { nurseId };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter)
      .populate("patientId", "name email")
      .sort({ dateTime: 1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Appointment.countDocuments(filter);

    return res.status(200).json({
      success: true,
      appointments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la récupération des rendez-vous",
      error: error.message,
    });
  }
};

// 📋 عرض جميع طلبات المواعيد المتاحة (للممرضين)
export const getAvailableAppointments = async (req, res) => {
  try {
    const nurseId = req.user.userId;

    // التحقق من أن المستخدم ممرض
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Accès non autorisé",
      });
    }

    const { page = 1, limit = 10 } = req.query;

    const appointments = await Appointment.find({ 
      status: "pending",
      nurseId: null,
      dateTime: { $gt: new Date() }
    })
      .populate("patientId", "name email")
      .sort({ dateTime: 1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Appointment.countDocuments({ 
      status: "pending",
      nurseId: null,
      dateTime: { $gt: new Date() }
    });

    return res.status(200).json({
      success: true,
      appointments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la récupération des rendez-vous disponibles",
      error: error.message,
    });
  }
};

// ✅ قبول الموعد (للممرض)
export const acceptAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const nurseId = req.user.userId;

    // التحقق من أن المستخدم ممرض
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les infirmiers peuvent accepter des rendez-vous",
      });
    }

    const appointment = await Appointment.findById(appointmentId);
    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: "Rendez-vous non trouvé",
      });
    }

    if (appointment.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Ce rendez-vous n'est plus disponible",
      });
    }

    // التحقق من عدم وجود تعارض في مواعيد الممرض
    const conflictingAppointment = await Appointment.findOne({
      nurseId,
      dateTime: {
        $gte: new Date(appointment.dateTime.getTime() - 30 * 60 * 1000),
        $lte: new Date(appointment.dateTime.getTime() + appointment.duration * 60 * 1000),
      },
      status: { $in: ["accepted", "pending"] },
    });

    if (conflictingAppointment) {
      return res.status(409).json({
        success: false,
        message: "Vous avez déjà un rendez-vous à cette période",
      });
    }

    appointment.nurseId = nurseId;
    appointment.status = "accepted";
    await appointment.save();

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patientId", "name email")
      .populate("nurseId", "name email");

    // إرسال إشعار للمريض
    try {
      await sendAppointmentEmail({
        to: populatedAppointment.patientId.email,
        patientName: populatedAppointment.patientId.name,
        nurseName: populatedAppointment.nurseId.name,
        appointmentDate: appointment.dateTime,
        reason: appointment.reason,
        isAccepted: true,
      });
    } catch (emailError) {
      console.log("Erreur envoi email patient:", emailError.message);
    }

    // Emit Socket.io notification
    try {
      const io = getIO();
      io.to(`user:${populatedAppointment.patientId._id}`).emit("appointment:updated", { type: "appointment:accepted", data: populatedAppointment });
    } catch (_err) {
      console.warn("Socket emission error (non bloquante):", _err.message);
    }

    return res.status(200).json({
      success: true,
      message: "Rendez-vous accepté avec succès",
      appointment: populatedAppointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de l'acceptation du rendez-vous",
      error: error.message,
    });
  }
};

// ❌ رفض الموعد (للممرض)
export const rejectAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { rejectionReason } = req.body;
    const nurseId = req.user.userId;

    // التحقق من أن المستخدم ممرض
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les infirmiers peuvent rejeter des rendez-vous",
      });
    }

    const appointment = await Appointment.findById(appointmentId);
    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: "Rendez-vous non trouvé",
      });
    }

    if (appointment.status !== "pending") {
      return res.status(400).json({
        success: false,
        message: "Ce rendez-vous ne peut pas être rejeté",
      });
    }

    appointment.status = "rejected";
    appointment.rejectionReason = rejectionReason || "Rendez-vous rejeté par l'infirmier";
    await appointment.save();

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patientId", "name email")
      .populate("nurseId", "name email");

    return res.status(200).json({
      success: true,
      message: "Rendez-vous rejeté",
      appointment: populatedAppointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors du rejet du rendez-vous",
      error: error.message,
    });
  }
};

// 🚫 إلغاء الموعد (للمريض)
export const cancelAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { cancellationReason } = req.body;
    const patientId = req.user.userId;

    // التحقق من أن المستخدم مريض
    const patient = await User.findById(patientId);
    if (!patient || !patient.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les patients peuvent annuler leurs rendez-vous",
      });
    }

    const appointment = await Appointment.findById(appointmentId);
    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: "Rendez-vous non trouvé",
      });
    }

    if (appointment.patientId.toString() !== patientId) {
      return res.status(403).json({
        success: false,
        message: "Ce rendez-vous ne vous appartient pas",
      });
    }

    if (!["pending", "accepted"].includes(appointment.status)) {
      return res.status(400).json({
        success: false,
        message: "Ce rendez-vous ne peut pas être annulé",
      });
    }

    // التحقق من أن الموعد ليس خلال 24 ساعة القادمة
    const now = new Date();
    const appointmentTime = new Date(appointment.dateTime);
    const timeDiff = appointmentTime.getTime() - now.getTime();
    const hoursDiff = timeDiff / (1000 * 60 * 60);

    if (hoursDiff < 24) {
      return res.status(400).json({
        success: false,
        message: "Les rendez-vous doivent être annulés au moins 24 heures à l'avance",
      });
    }

    appointment.status = "cancelled";
    appointment.cancelledAt = new Date();
    appointment.cancelledBy = patientId;
    appointment.notes = appointment.notes 
      ? `${appointment.notes}\n\nAnnulation: ${cancellationReason || "Annulé par le patient"}`
      : `Annulation: ${cancellationReason || "Annulé par le patient"}`;
    
    await appointment.save();

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patientId", "name email")
      .populate("nurseId", "name email");

    return res.status(200).json({
      success: true,
      message: "Rendez-vous annulé avec succès",
      appointment: populatedAppointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de l'annulation du rendez-vous",
      error: error.message,
    });
  }
};

// ✅ إكمال الموعد (للممرض)
export const completeAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { completionNotes } = req.body;
    const nurseId = req.user.userId;

    // التحقق من أن المستخدم ممرض
    const nurse = await User.findById(nurseId);
    if (!nurse || nurse.isPatient) {
      return res.status(403).json({
        success: false,
        message: "Seuls les infirmiers peuvent compléter des rendez-vous",
      });
    }

    const appointment = await Appointment.findById(appointmentId);
    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: "Rendez-vous non trouvé",
      });
    }

    if (appointment.nurseId.toString() !== nurseId) {
      return res.status(403).json({
        success: false,
        message: "Ce rendez-vous ne vous est pas assigné",
      });
    }

    if (appointment.status !== "accepted") {
      return res.status(400).json({
        success: false,
        message: "Seuls les rendez-vous acceptés peuvent être complétés",
      });
    }

    appointment.status = "completed";
    appointment.completedAt = new Date();
    if (completionNotes) {
      appointment.notes = appointment.notes 
        ? `${appointment.notes}\n\nNotes de complétion: ${completionNotes}`
        : `Notes de complétion: ${completionNotes}`;
    }
    
    await appointment.save();

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patientId", "name email")
      .populate("nurseId", "name email");

    return res.status(200).json({
      success: true,
      message: "Rendez-vous complété avec succès",
      appointment: populatedAppointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la complétion du rendez-vous",
      error: error.message,
    });
  }
};

// 📅 تقويم المواعيد (عرض بالشهر/الأسبوع)
export const getAppointmentsCalendar = async (req, res) => {
  try {
    const { month, year, view = "month" } = req.query;
    const userId = req.user.userId;

    // التحقق من نوع المستخدم
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Utilisateur non trouvé",
      });
    }

    const currentDate = new Date();
    const targetMonth = month ? parseInt(month) - 1 : currentDate.getMonth();
    const targetYear = year ? parseInt(year) : currentDate.getFullYear();

    let startDate, endDate;

    if (view === "week") {
      // عرض الأسبوع الحالي
      const startOfWeek = new Date(currentDate);
      startOfWeek.setDate(currentDate.getDate() - currentDate.getDay());
      startOfWeek.setHours(0, 0, 0, 0);

      const endOfWeek = new Date(startOfWeek);
      endOfWeek.setDate(startOfWeek.getDate() + 6);
      endOfWeek.setHours(23, 59, 59, 999);

      startDate = startOfWeek;
      endDate = endOfWeek;
    } else {
      // عرض الشهر
      startDate = new Date(targetYear, targetMonth, 1);
      endDate = new Date(targetYear, targetMonth + 1, 0);
      endDate.setHours(23, 59, 59, 999);
    }

    const filter = {
      dateTime: { $gte: startDate, $lte: endDate },
    };

    if (user.isPatient) {
      filter.patientId = userId;
    } else {
      filter.nurseId = userId;
    }

    const appointments = await Appointment.find(filter)
      .populate(user.isPatient ? "nurseId" : "patientId", "name email")
      .sort({ dateTime: 1 });

    return res.status(200).json({
      success: true,
      appointments,
      period: {
        start: startDate,
        end: endDate,
        view,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la récupération du calendrier",
      error: error.message,
    });
  }
};

// 📋 Récupérer tous les rendez-vous (Admin)
export const getAllAppointments = async (req, res) => {
  try {
    const { status, page = 1, limit = 50 } = req.query;

    const filter = {};
    if (status) filter.status = status;

    const appointments = await Appointment.find(filter)
      .populate("patientId", "name email phone")
      .populate("nurseId", "name email phone")
      .sort({ dateTime: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Appointment.countDocuments(filter);

    return res.status(200).json({
      success: true,
      appointments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la récupération des rendez-vous",
      error: error.message,
    });
  }
};
