import User from "../models/userModel.js";
import { getMessage, sendLocalizedResponse } from "../services/languageService.js";

// @desc    Get user's settings
// @route   GET /api/v1/settings
// @access  Private
export const getUserSettings = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select(
      "name email role isVerified"
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: getMessage("userNotFound", "en"),
      });
    }

    res.status(200).json({
      success: true,
      user,
    });
  } catch (error) {
    console.error("Error getting settings:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", "en"),
    });
  }
};

// @desc    Update user profile
// @route   PUT /api/v1/settings/profile
// @access  Private
export const updateProfile = async (req, res) => {
  try {
    const { name, email, phone } = req.body;
    const userId = req.user._id;
    const lang = "en";

    // Check if email already exists (if changing email)
    if (email) {
      const existingUser = await User.findOne({
        email,
        _id: { $ne: userId },
      });
      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: getMessage("emailExists", lang),
        });
      }
    }

    const updates = {};
    if (name) updates.name = name;
    if (email) updates.email = email;
    if (phone) updates.phone = phone;

    const user = await User.findByIdAndUpdate(userId, updates, {
      new: true,
      runValidators: true,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: getMessage("userNotFound", lang),
      });
    }

    sendLocalizedResponse(res, 200, "success", { user }, lang);
  } catch (error) {
    console.error("Error updating profile:", error);
    res.status(500).json({
      success: false,
      message: getMessage("serverError", "en"),
    });
  }
};

// @desc    Get supported languages
// @route   GET /api/v1/settings/languages
// @access  Public
export const getSupportedLanguages = async (req, res) => {
  try {
    const languages = [
      { code: "en", name: "English", flag: "🇬🇧", nativeName: "English" },
      { code: "fr", name: "Français", flag: "🇫🇷", nativeName: "Français" },
      { code: "ar", name: "العربية", flag: "🇸🇦", nativeName: "العربية" },
    ];

    res.status(200).json({
      success: true,
      languages,
      defaultLanguage: "fr",
    });
  } catch (error) {
    console.error("Error getting languages:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
};
