import mongoose from "mongoose";
import dotenv from "dotenv";
import dns from "dns";

export const connectDB = async () => {
  try {
    if (!process.env.MONGO_URI) {
      console.error("Erreur critique: MONGO_URI n'est pas défini dans les variables d'environnement. Avez-vous oublié de créer le fichier .env sur l'autre PC ? ❌");
      process.exit(1);
    }
    dns.setServers(["8.8.8.8", "8.8.4.4"]);
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Connexion avec la base de données MongoDB réussie ✅");
  } catch (error) {
    console.error("Erreur de connexion à la base de données MongoDB ❌", error);
    process.exit(1);
  }
};