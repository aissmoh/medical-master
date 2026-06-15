import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import User from "./models/userModel.js";

let io;

export const initSocket = (server) => {
  io = new Server(server, {
    cors: {
      origin: true,
      credentials: true,
    },
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) {
        return next(new Error("Token manquant"));
      }
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.userId).select("name isPatient assignedNurse");
      if (!user) {
        return next(new Error("Utilisateur non trouvé"));
      }
      socket.user = user;
      next();
    } catch (err) {
      next(new Error("Authentification échouée"));
    }
  });

  io.on("connection", (socket) => {
    console.log(`Socket connecté: ${socket.user.name} (${socket.id})`);

    // Join user room for message delivery
    socket.join(`user:${socket.user._id}`);

    if (socket.user.isPatient) {
      socket.join(`patient:${socket.user._id}`);
      console.log(`Patient ${socket.user.name} a rejoint sa room`);
    } else {
      socket.join(`nurse:${socket.user._id}`);
      console.log(`Infirmier ${socket.user.name} a rejoint sa room`);
    }

    socket.on("subscribe:patient", (patientId) => {
      socket.join(`patient:${patientId}`);
      console.log(`${socket.user.name} suit le patient ${patientId}`);
    });

    socket.on("unsubscribe:patient", (patientId) => {
      socket.leave(`patient:${patientId}`);
    });

    socket.on("subscribe:all", () => {
      socket.join("vitals:all");
      console.log(`${socket.user.name} suit TOUS les patients`);
    });

    socket.on("unsubscribe:all", () => {
      socket.leave("vitals:all");
      console.log(`${socket.user.name} ne suit plus tous les patients`);
    });

    socket.on("disconnect", () => {
      console.log(`Socket déconnecté: ${socket.user.name} (${socket.id})`);
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    throw new Error("Socket.io pas encore initialisé");
  }
  return io;
};
