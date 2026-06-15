// Language Service for Backend
// Provides translated messages based on user's preferred language

const translations = {
  en: {
    welcome: "Welcome",
    loginSuccess: "Login successful",
    loginFailed: "Invalid credentials",
    logoutSuccess: "Logout successful",
    patientNotFound: "Patient not found",
    nurseNotFound: "Nurse not found",
    accessDenied: "Access denied",
    serverError: "Server error",
    taskCreated: "Task created successfully",
    taskUpdated: "Task updated successfully",
    taskCompleted: "Task completed",
    taskDeleted: "Task deleted",
    alertAcknowledged: "Alert acknowledged",
    alertResolved: "Alert resolved",
    sosAlertCreated: "SOS alert created",
    vitalsSaved: "Vitals saved successfully",
    invalidData: "Invalid data provided",
    unauthorized: "Unauthorized access",
    tokenRequired: "Authentication token required",
    tokenExpired: "Token expired",
    emailExists: "Email already exists",
    phoneExists: "Phone number already exists",
    invalidEmail: "Invalid email format",
    weakPassword: "Password is too weak",
    userNotFound: "User not found",
    incorrectPassword: "Incorrect password",
    accountLocked: "Account is locked",
    accountNotVerified: "Account not verified",
    otpSent: "Verification code sent",
    otpInvalid: "Invalid verification code",
    passwordReset: "Password reset successfully",
    emailNotFound: "Email not found",
    cannotDeleteSelf: "Cannot delete your own account",
    noPatientsAssigned: "No patients assigned",
    noTasksFound: "No tasks found",
    noAlertsFound: "No alerts found",
    notificationSent: "Notification sent",
  },
  fr: {
    welcome: "Bienvenue",
    loginSuccess: "Connexion réussie",
    loginFailed: "Identifiants invalides",
    logoutSuccess: "Déconnexion réussie",
    patientNotFound: "Patient non trouvé",
    nurseNotFound: "Infirmier non trouvé",
    accessDenied: "Accès refusé",
    serverError: "Erreur serveur",
    taskCreated: "Tâche créée avec succès",
    taskUpdated: "Tâche mise à jour avec succès",
    taskCompleted: "Tâche terminée",
    taskDeleted: "Tâche supprimée",
    alertAcknowledged: "Alerte reconnue",
    alertResolved: "Alerte résolue",
    sosAlertCreated: "Alerte SOS créée",
    vitalsSaved: "Signes vitaux enregistrés",
    invalidData: "Données invalides",
    unauthorized: "Accès non autorisé",
    tokenRequired: "Token d'authentification requis",
    tokenExpired: "Token expiré",
    emailExists: "Email déjà existant",
    phoneExists: "Numéro de téléphone déjà existant",
    invalidEmail: "Format d'email invalide",
    weakPassword: "Mot de passe trop faible",
    userNotFound: "Utilisateur non trouvé",
    incorrectPassword: "Mot de passe incorrect",
    accountLocked: "Compte verrouillé",
    accountNotVerified: "Compte non vérifié",
    otpSent: "Code de vérification envoyé",
    otpInvalid: "Code de vérification invalide",
    passwordReset: "Mot de passe réinitialisé",
    emailNotFound: "Email non trouvé",
    cannotDeleteSelf: "Impossible de supprimer votre propre compte",
    noPatientsAssigned: "Aucun patient assigné",
    noTasksFound: "Aucune tâche trouvée",
    noAlertsFound: "Aucune alerte trouvée",
    notificationSent: "Notification envoyée",
  },
  ar: {
    welcome: "أهلاً وسهلاً",
    loginSuccess: "تم تسجيل الدخول بنجاح",
    loginFailed: "بيانات الاعتماد غير صالحة",
    logoutSuccess: "تم تسجيل الخروج بنجاح",
    patientNotFound: "لم يتم العثور على المريض",
    nurseNotFound: "لم يتم العثور على الممرض",
    accessDenied: "الوصول مرفوض",
    serverError: "خطأ في الخادم",
    taskCreated: "تم إنشاء المهمة بنجاح",
    taskUpdated: "تم تحديث المهمة بنجاح",
    taskCompleted: "تم إكمال المهمة",
    taskDeleted: "تم حذف المهمة",
    alertAcknowledged: "تم الاعتراف بالتنبيه",
    alertResolved: "تم حل التنبيه",
    sosAlertCreated: "تم إنشاء تنبيه SOS",
    vitalsSaved: "تم حفظ العلامات الحيوية",
    invalidData: "بيانات غير صالحة",
    unauthorized: "وصول غير مصرح",
    tokenRequired: "مطلوب رمز المصادقة",
    tokenExpired: "انتهت صلاحية الرمز",
    emailExists: "البريد الإلكتروني موجود بالفعل",
    phoneExists: "رقم الهاتف موجود بالفعل",
    invalidEmail: "تنسيق بريد إلكتروني غير صالح",
    weakPassword: "كلمة المرور ضعيفة جداً",
    userNotFound: "المستخدم غير موجود",
    incorrectPassword: "كلمة المرور غير صحيحة",
    accountLocked: "الحساب مقفل",
    accountNotVerified: "الحساب غير مُحَقَّق",
    otpSent: "تم إرسال رمز التحقق",
    otpInvalid: "رمز التحقق غير صالح",
    passwordReset: "تم إعادة تعيين كلمة المرور",
    emailNotFound: "البريد الإلكتروني غير موجود",
    cannotDeleteSelf: "لا يمكن حذف حسابك الخاص",
    noPatientsAssigned: "لم يتم تعيين أي مرضى",
    noTasksFound: "لم يتم العثور على مهام",
    noAlertsFound: "لم يتم العثور على تنبيهات",
    notificationSent: "تم إرسال الإشعار",
  },
};

const supportedLanguages = ["en", "fr", "ar"];
const defaultLanguage = "fr";

/**
 * Get translated message
 * @param {string} key - Translation key
 * @param {string} lang - Language code (en, fr, ar)
 * @returns {string} Translated message
 */
export const getMessage = (key, lang = defaultLanguage) => {
  const language = supportedLanguages.includes(lang) ? lang : defaultLanguage;
  return translations[language][key] || translations[defaultLanguage][key] || key;
};

/**
 * Get user's preferred language from request
 * @param {Object} req - Express request object
 * @returns {string} Language code
 */
export const getUserLanguage = (req) => {
  // Check if user has preferred language in their profile
  if (req.user && req.user.preferredLanguage) {
    return req.user.preferredLanguage;
  }

  // Check Accept-Language header
  const acceptLanguage = req.headers["accept-language"];
  if (acceptLanguage) {
    const requestedLang = acceptLanguage.split(",")[0].split("-")[0];
    if (supportedLanguages.includes(requestedLang)) {
      return requestedLang;
    }
  }

  return defaultLanguage;
};

/**
 * Create response with translated message
 * @param {Object} res - Express response object
 * @param {number} statusCode - HTTP status code
 * @param {string} messageKey - Translation key
 * @param {Object} data - Additional data
 * @param {string} lang - Language code
 */
export const sendLocalizedResponse = (
  res,
  statusCode,
  messageKey,
  data = {},
  lang = defaultLanguage
) => {
  const message = getMessage(messageKey, lang);

  res.status(statusCode).json({
    success: statusCode >= 200 && statusCode < 300,
    message,
    ...data,
  });
};

export default {
  getMessage,
  getUserLanguage,
  sendLocalizedResponse,
  supportedLanguages,
  defaultLanguage,
};
