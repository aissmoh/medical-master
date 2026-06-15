import express from "express";
import http from "http";
import dotenv from "dotenv";
import cookieParser from "cookie-parser";
import cors from "cors";
import passport from "passport";

import { connectDB } from "./config/db.js";
import authRoutes from "./routes/authRoutes.js";
import appointmentRoutes from "./routes/appointmentRoutes.js";
import messageRoutes from "./routes/messageRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import emergencyRoutes from "./routes/emergencyRoutes.js";
import vitalSignsRoutes from "./routes/vitalSignsRoutes.js";
import vitalSignsTablesRoutes from "./routes/vitalSignsTablesRoutes.js";
import nurseRoutes from "./routes/nurseRoutes.js";
import patientRoutes from "./routes/patientRoutes.js";
import taskRoutes from "./routes/taskRoutes.js";
import settingsRoutes from "./routes/settingsRoutes.js";
import { initSocket } from "./socket.js";


dotenv.config();

const app = express();
const server = http.createServer(app);
const port = process.env.PORT || 5000;
const host = "0.0.0.0";

app.use(
  cors({
    origin: true,
    credentials: true,
  })
);
app.use(express.json());
app.use(cookieParser());
app.use(passport.initialize());

app.use((req, _res, next) => {
  console.log(
    `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} - origin: ${req.headers.origin || "N/A"}`
  );
  next();
});

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/appointments", appointmentRoutes);
app.use("/api/v1/messages", messageRoutes);
app.use("/api/v1/users", userRoutes);
app.use("/api/v1/emergency", emergencyRoutes);
app.use("/api/v1/vitals", vitalSignsRoutes);
app.use("/api/v1/vitals/tables", vitalSignsTablesRoutes);
app.use("/api/v1/nurse", nurseRoutes);
app.use("/api/v1/patient", patientRoutes);
app.use("/api/v1/tasks", taskRoutes);
app.use("/api/v1/settings", settingsRoutes);


app.get("/", (req, res) => {
  res.json({
    message: "Backend Medical Master en cours d'execution",
    port,
    status: "ok",
  });
});

const startServer = async () => {
  await connectDB();

  initSocket(server);

  server.listen(port, host, () => {
    console.log(`Serveur en cours d'execution sur http://localhost:${port} ✅`);
    console.log(`Socket.io prêt pour le temps réel 🚀`);
  });
};

startServer();
