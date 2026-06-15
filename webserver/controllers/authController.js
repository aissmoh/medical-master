import otpGenerator from "otp-generator";
import jwt from "jsonwebtoken";

import { sendOtpEmail } from "../config/mail.js";
import User from "../models/userModel.js";

const OTP_EXPIRATION_MINUTES = 10;
const JWT_EXPIRATION = "7d";

const getNormalizedRole = ({ isPatient, role }) => {
  // If isPatient is explicitly provided as boolean, use it
  if (typeof isPatient === "boolean") {
    return isPatient;
  }

  // Handle string values: isPatient can be "true"/"false" from some clients
  if (typeof isPatient === "string") {
    if (isPatient.toLowerCase() === "true") return true;
    if (isPatient.toLowerCase() === "false") return false;
  }

  // Handle role as string (e.g. role: "patient" or role: "nurse")
  if (typeof role === "string") {
    const r = role.toLowerCase().trim();
    if (r === "patient") return true;
    if (r === "nurse" || r === "garde malade" || r === "garde_malade") return false;
  }

  // Handle role as boolean (legacy)
  if (typeof role === "boolean") {
    return role;
  }

  return null;
};

export const signUp = async (req, res) => {
  try {
    const { name, email, password, confirmPassword, isPatient, role, phone, groupeSanguin } = req.body;

    const normalizedName = name?.trim();
    const normalizedEmail = email?.trim().toLowerCase();
    const normalizedRole = getNormalizedRole({ isPatient, role });

    const normalizedPhone = phone?.trim();

    if (
      !normalizedName ||
      !normalizedEmail ||
      !password ||
      !confirmPassword ||
      normalizedRole === null ||
      !normalizedPhone
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Les champs nom, email, téléphone, mot de passe, confirmation et rôle sont requis.",
      });
    }

    if (!/^0[567]\d{8}$/.test(normalizedPhone)) {
      return res.status(400).json({
        success: false,
        message:
          "Le numéro de téléphone doit commencer par 05, 06 ou 07 et contenir 10 chiffres.",
      });
    }

    if (normalizedRole === true && !groupeSanguin) {
      return res.status(400).json({
        success: false,
        message: "Le groupe sanguin est requis pour les patients.",
      });
    }

    if (password !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: "Les mots de passe ne correspondent pas.",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Le mot de passe doit contenir au moins 6 caracteres.",
      });
    }

    const existingUser = await User.findOne({ email: normalizedEmail });

    if (existingUser?.isVerified) {
      return res.status(409).json({
        success: false,
        message: "Un utilisateur avec cet email existe deja.",
      });
    }

    const otp = otpGenerator.generate(4, {
      upperCaseAlphabets: false,
      lowerCaseAlphabets: false,
      specialChars: false,
      digits: true,
    });
    const otpExpiresAt = new Date(
      Date.now() + OTP_EXPIRATION_MINUTES * 60 * 1000
    );

    let user = existingUser;

    if (user) {
      user.name = normalizedName;
      user.email = normalizedEmail;
      user.password = password;
      user.isPatient = normalizedRole;
      user.phone = normalizedPhone;
      user.groupeSanguin = normalizedRole === true ? groupeSanguin : null;
      user.isVerified = false;
      user.otpCode = otp;
      user.otpExpiresAt = otpExpiresAt;

      await user.save();
    } else {
      user = await User.create({
        name: normalizedName,
        email: normalizedEmail,
        password,
        isPatient: normalizedRole,
        phone: normalizedPhone,
        groupeSanguin: normalizedRole === true ? groupeSanguin : null,
        otpCode: otp,
        otpExpiresAt,
      });
    }

    await sendOtpEmail({
      to: normalizedEmail,
      name: normalizedName,
      otp,
    });

    return res.status(200).json({
      success: true,
      message: "Code OTP envoye par email. Veuillez verifier votre compte.",
      email: normalizedEmail,
      expiresInMinutes: OTP_EXPIRATION_MINUTES,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la creation du compte.",
      error: error.message,
    });
  }
};

export const verifySignUpOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;

    const normalizedEmail = email?.trim().toLowerCase();
    const normalizedOtp = otp?.toString().trim();

    if (!normalizedEmail || !normalizedOtp) {
      return res.status(400).json({
        success: false,
        message: "L'email et le code OTP sont requis.",
      });
    }

    if (!/^\d{4}$/.test(normalizedOtp)) {
      return res.status(400).json({
        success: false,
        message: "Le code OTP doit contenir exactement 4 chiffres.",
      });
    }

    const user = await User.findOne({ email: normalizedEmail }).select(
      "+otpCode +otpExpiresAt"
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Aucun compte en attente avec cet email.",
      });
    }

    if (user.isVerified) {
      return res.status(400).json({
        success: false,
        message: "Ce compte est deja verifie.",
      });
    }

    if (!user.otpCode || !user.otpExpiresAt) {
      return res.status(400).json({
        success: false,
        message: "Aucun code OTP actif pour ce compte.",
      });
    }

    if (user.otpExpiresAt.getTime() < Date.now()) {
      user.otpCode = null;
      user.otpExpiresAt = null;
      await user.save();

      return res.status(400).json({
        success: false,
        message: "Le code OTP a expire. Veuillez relancer l'inscription.",
      });
    }

    const isOtpValid = await user.compareOtp(normalizedOtp);

    if (!isOtpValid) {
      return res.status(400).json({
        success: false,
        message: "Code OTP invalide.",
      });
    }

    user.isVerified = true;
    user.otpCode = null;
    user.otpExpiresAt = null;
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Compte verifie avec succes.",
      user: {
        ...user.toJSON(),
        role: user.isPatient ? "patient" : "garde malade",
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la verification OTP.",
      error: error.message,
    });
  }
};

export const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const normalizedEmail = email?.trim().toLowerCase();
    const normalizedPassword = password?.trim();

    if (!normalizedEmail || !normalizedPassword) {
      return res.status(400).json({
        success: false,
        message: "L'email et le mot de passe sont requis.",
      });
    }

    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Aucun compte n'est associe a cet email.",
      });
    }

    if (!user.isVerified) {
      return res.status(403).json({
        success: false,
        message: "Veuillez verifier votre compte avant de vous connecter.",
      });
    }

    const isPasswordValid = await user.comparePassword(normalizedPassword);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Mot de passe incorrect.",
      });
    }

    const token = jwt.sign(
      {
        userId: user._id,
        email: user.email,
        isPatient: user.isPatient,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: JWT_EXPIRATION,
      }
    );

    return res.status(200).json({
      success: true,
      message: "Connexion reussie.",
      token,
      user: {
        ...user.toJSON(),
        role: user.isPatient ? "patient" : "garde malade",
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la connexion.",
      error: error.message,
    });
  }
};

export const logout = async (req, res) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "Token d'authentification requis.",
      });
    }

    // Verify token and extract user info
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // In a more advanced implementation, you could:
    // - Add token to a blacklist
    // - Update user's lastLogout timestamp
    // - Invalidate all sessions for the user

    return res.status(200).json({
      success: true,
      message: "Deconnexion reussie.",
    });
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: "Token invalide ou expire.",
      });
    }

    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de la deconnexion.",
      error: error.message,
    });
  }
};
