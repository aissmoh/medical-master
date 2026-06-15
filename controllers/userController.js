import User from "../models/userModel.js";
import cloudinary from "../config/cloudinary.js";

// ✅ Créer un utilisateur (admin / sans OTP)
export const createUser = async (req, res) => {
  try {
    const { name, email, password, phone, role, groupeSanguin, assignedNurse, roomInfo } = req.body;

    if (!name || !email || !password || !phone || !role) {
      return res.status(400).json({ success: false, message: "Nom, email, mot de passe, téléphone et rôle sont requis." });
    }

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(409).json({ success: false, message: "Un compte avec cet email existe déjà." });
    }

    const isPatient = role === 'patient';
    const user = await User.create({
      name, email, password, phone,
      isPatient,
      groupeSanguin: isPatient ? (groupeSanguin || 'O+') : undefined,
      assignedNurse: assignedNurse || null,
      roomInfo: roomInfo || { chamber: null, bed: null },
      isVerified: true,
    });

    return res.status(201).json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la création", error: error.message });
  }
};

// ✅ Modifier un utilisateur par ID (admin)
export const updateUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const { name, email, phone, password, role, groupeSanguin, assignedNurse, isVerified, roomInfo } = req.body;
    const update = {};

    if (name !== undefined) update.name = name;
    if (email !== undefined) update.email = email;
    if (phone !== undefined) update.phone = phone;
    if (role !== undefined) update.isPatient = role === 'patient';
    if (groupeSanguin !== undefined) update.groupeSanguin = groupeSanguin;
    if (assignedNurse !== undefined) update.assignedNurse = assignedNurse;
    if (isVerified !== undefined) update.isVerified = isVerified;
    if (roomInfo !== undefined) update.roomInfo = roomInfo;
    if (password) update.password = password;

    const user = await User.findByIdAndUpdate(userId, update, { new: true, runValidators: true });

    if (!user) {
      return res.status(404).json({ success: false, message: "Utilisateur non trouvé." });
    }

    return res.status(200).json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la modification", error: error.message });
  }
};

// ✅ Supprimer un utilisateur par ID (admin)
export const deleteUser = async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findByIdAndDelete(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: "Utilisateur non trouvé." });
    }

    return res.status(200).json({ success: true, message: "Utilisateur supprimé avec succès." });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Erreur lors de la suppression", error: error.message });
  }
};

// Récupérer tous les utilisateurs (sauf l'utilisateur connecté)
export const getUsers = async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    const { role, search } = req.query;

    const filter = {
      _id: { $ne: currentUserId }, // Exclure l'utilisateur connecté
      isVerified: true, // Seulement les utilisateurs vérifiés
    };

    // Filtrer par rôle
    if (role === 'patient') {
      filter.isPatient = true;
    } else if (role === 'nurse' || role === 'companion') {
      filter.isPatient = false;
    }

    // Recherche par nom
    if (search) {
      filter.name = { $regex: search, $options: 'i' };
    }

    const users = await User.find(filter)
      .select('-password -otpCode -otpExpiresAt -email')
      .sort({ name: 1 });

    return res.status(200).json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des utilisateurs",
      error: error.message,
    });
  }
};

// Récupérer les infirmiers/soignants disponibles
export const getNurses = async (req, res) => {
  try {
    const nurses = await User.find({
      isPatient: false,
      isVerified: true,
    })
      .select('-password -otpCode -otpExpiresAt')
      .sort({ name: 1 });

    return res.status(200).json({
      success: true,
      count: nurses.length,
      data: nurses,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des infirmiers",
      error: error.message,
    });
  }
};

// Récupérer le profil de l'utilisateur connecté
export const getMyProfile = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId).select('-password -otpCode -otpExpiresAt');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Utilisateur non trouvé",
      });
    }

    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération du profil",
      error: error.message,
    });
  }
};

// Récupérer un utilisateur par ID
export const getUserById = async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findById(userId).select('-password -otpCode -otpExpiresAt');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Utilisateur non trouvé",
      });
    }

    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération de l'utilisateur",
      error: error.message,
    });
  }
};

// Rechercher des utilisateurs pour la messagerie
export const searchUsers = async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    const { query } = req.query;

    if (!query || query.trim().length < 2) {
      return res.status(400).json({
        success: false,
        message: "La recherche doit contenir au moins 2 caractères",
      });
    }

    const users = await User.find({
      _id: { $ne: currentUserId },
      isVerified: true,
      name: { $regex: query.trim(), $options: 'i' },
    })
      .select('-password -otpCode -otpExpiresAt')
      .limit(10);

    return res.status(200).json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la recherche",
      error: error.message,
    });
  }
};

// Mettre à jour le profil de l'utilisateur connecté
export const updateMyProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { name, phone, groupeSanguin, address } = req.body;

    const update = {};
    if (name !== undefined) update.name = name;
    if (phone !== undefined) update.phone = phone;
    if (groupeSanguin !== undefined) update.groupeSanguin = groupeSanguin;
    if (address !== undefined) update.address = address;

    const user = await User.findByIdAndUpdate(userId, update, {
      new: true,
      runValidators: true,
    }).select('-password -otpCode -otpExpiresAt');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Utilisateur non trouvé",
      });
    }

    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de la mise à jour du profil",
      error: error.message,
    });
  }
};

// Uploader une photo de profil
export const updateProfilePhoto = async (req, res) => {
  try {
    const userId = req.user.userId;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Aucune image fournie",
      });
    }

    const allowedExts = ["jpg", "jpeg", "png", "gif", "webp"];
    const ext = req.file.originalname?.split('.').pop()?.toLowerCase();
    if (!ext || !allowedExts.includes(ext)) {
      return res.status(400).json({
        success: false,
        message: "Format d'image non supporté. Utilisez JPG, PNG, GIF ou WEBP.",
      });
    }

    const mimeMap = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif", webp: "image/webp" };
    const mime = mimeMap[ext] || "image/jpeg";

    const b64 = Buffer.from(req.file.buffer).toString("base64");
    const dataUri = `data:${mime};base64,${b64}`;

    const result = await cloudinary.uploader.upload(dataUri, {
      folder: "profiles",
      width: 400,
      height: 400,
      crop: "fill",
    });

    const user = await User.findByIdAndUpdate(
      userId,
      { profileImage: result.secure_url },
      { new: true }
    ).select('-password -otpCode -otpExpiresAt');

    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur lors de l'upload de la photo",
      error: error.message,
    });
  }
};
