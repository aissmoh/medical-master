import bcrypt from "bcryptjs";
import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Le nom est requis"],
      trim: true,
    },
    email: {
      type: String,
      required: [true, "L'email est requis"],
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: [true, "Le mot de passe est requis"],
      minlength: 6,
    },
    phone: {
      type: String,
      required: [true, "Le numéro de téléphone est requis"],
      validate: {
        validator: function (v) {
          return /^0[567]\d{8}$/.test(v);
        },
        message:
          "Le numéro de téléphone doit commencer par 05, 06 ou 07 et contenir 10 chiffres.",
      },
      trim: true,
    },
    isPatient: {
      type: Boolean,
      required: true,
    },
    groupeSanguin: {
      type: String,
      enum: {
        values: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
        message: "Groupe sanguin invalide.",
      },
      required: [
        function () {
          return this.isPatient === true;
        },
        "Le groupe sanguin est requis pour les patients.",
      ],
      default: null,
    },

    assignedNurse: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    roomInfo: {
      chamber: { type: String, default: null },
      bed: { type: String, default: null },
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    otpCode: {
      type: String,
      default: null,
      select: false,
    },
    otpExpiresAt: {
      type: Date,
      default: null,
      select: false,
    },
    // Photo de profil
    profileImage: {
      type: String,
      default: null,
    },
    // Adresse textuelle
    address: {
      type: String,
      default: null,
    },
    // Localisation GPS (pour les urgences et les soignants)
    location: {
      lat: {
        type: Number,
        default: null,
      },
      lng: {
        type: Number,
        default: null,
      },
      lastUpdated: {
        type: Date,
        default: null,
      },
    },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.password;
        delete ret.otpCode;
        delete ret.otpExpiresAt;
        return ret;
      },
    },
  }
);

userSchema.pre("save", async function hashPassword() {
  if (!this.isModified("password")) {
    if (this.isModified("otpCode") && this.otpCode) {
      this.otpCode = await bcrypt.hash(this.otpCode, 10);
    }
    return;
  }

  this.password = await bcrypt.hash(this.password, 10);

  if (this.isModified("otpCode") && this.otpCode) {
    this.otpCode = await bcrypt.hash(this.otpCode, 10);
  }
});

userSchema.methods.compareOtp = async function compareOtp(candidateOtp) {
  if (!this.otpCode) {
    return false;
  }

  return bcrypt.compare(candidateOtp, this.otpCode);
};

userSchema.methods.comparePassword = async function comparePassword(
  candidatePassword
) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model("User", userSchema);

export default User;
