import jwt from "jsonwebtoken";
import User from "../models/userModel.js";

export const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Token d'authentification requis",
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await User.findById(decoded.userId).select('-password -otpCode -otpExpiresAt');
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Utilisateur non trouvé",
      });
    }

    if (!user.isVerified) {
      return res.status(403).json({
        success: false,
        message: "Compte non vérifié",
      });
    }

    req.user = user;
    req.user.userId = user._id; // backward compatibility for controllers using req.user.userId
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: "Token invalide ou expiré",
      });
    }

    return res.status(500).json({
      success: false,
      message: "Erreur serveur lors de l'authentification",
      error: error.message,
    });
  }
};

export const requirePatient = (req, res, next) => {
  if (req.user && req.user.isPatient) {
    return next();
  }
  
  return res.status(403).json({
    success: false,
    message: "Accès réservé aux patients",
  });
};

export const requireNurse = (req, res, next) => {
  if (req.user && !req.user.isPatient) {
    return next();
  }
  
  return res.status(403).json({
    success: false,
    message: "Accès réservé aux infirmiers",
  });
};

