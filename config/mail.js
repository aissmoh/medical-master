import nodemailer from "nodemailer";



export const sendOtpEmail = async ({ to, name, otp }) => {

  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {

    throw new Error("La configuration EMAIL_USER / EMAIL_PASS est manquante.");

  }



  const transporter = nodemailer.createTransport({

    host: "smtp.gmail.com",

    port: 587,

    secure: false, // use TLS

    auth: {

      user: process.env.EMAIL_USER,

      pass: process.env.EMAIL_PASS,

    },

    // Force IPv4 to avoid IPv6 connection issues

    family: 4,

    tls: {

      rejectUnauthorized: false,

    },

  });



  await transporter.sendMail({

    from: process.env.EMAIL_USER,

    to,

    subject: "Code OTP - Verification de votre compte",

    html: `

      <div style="font-family: Arial, sans-serif; line-height: 1.6;">

        <h2>Bonjour ${name},</h2>

        <p>Voici votre code de verification Medical Master :</p>

        <div style="font-size: 28px; font-weight: bold; letter-spacing: 8px; margin: 16px 0;">

          ${otp}

        </div>

        <p>Ce code est valide pendant 10 minutes.</p>

        <p>Si vous n'etes pas a l'origine de cette demande, vous pouvez ignorer cet email.</p>

      </div>

    `,

  });
};

export const sendAppointmentEmail = async ({ 
  to, 
  patientName, 
  nurseName, 
  appointmentDate, 
  reason, 
  isAccepted = false 
}) => {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    throw new Error("La configuration EMAIL_USER / EMAIL_PASS est manquante.");
  }

  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 587,

    secure: false,

    secure: false, // use TLS

    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },

    family: 4,
    tls: {
      rejectUnauthorized: false,
    },
  });

  const formattedDate = new Date(appointmentDate).toLocaleString('fr-FR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  let subject, html;

  if (isAccepted) {
    subject = "Rendez-vous accepté - Medical Master";
    html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>Bonjour ${patientName},</h2>
        <p>Votre rendez-vous a été accepté par l'infirmier <strong>${nurseName}</strong>.</p>
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #28a745; margin-top: 0;">✅ Détails du rendez-vous</h3>
          <p><strong>Date:</strong> ${formattedDate}</p>
          <p><strong>Raison:</strong> ${reason}</p>
          <p><strong>Infirmier:</strong> ${nurseName}</p>
        </div>
        <p>Veuillez être présent à l'heure indiquée.</p>
        <p>Cordialement,<br>L'équipe Medical Master</p>
      </div>
    `;
  } else if (nurseName) {
    // Notification pour l'infirmier (nouvelle demande)
    subject = "Nouvelle demande de rendez-vous - Medical Master";
    html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>Bonjour ${nurseName},</h2>
        <p>Une nouvelle demande de rendez-vous est disponible.</p>
        <div style="background-color: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #856404; margin-top: 0;">📅 Détails du rendez-vous</h3>
          <p><strong>Patient:</strong> ${patientName}</p>
          <p><strong>Date:</strong> ${formattedDate}</p>
          <p><strong>Raison:</strong> ${reason}</p>
        </div>
        <p>Vous pouvez consulter cette demande dans votre espace et l'accepter si vous êtes disponible.</p>
        <p>Cordialement,<br>L'équipe Medical Master</p>
      </div>
    `;
  } else {
    // Notification pour le patient (création)
    subject = "Demande de rendez-vous envoyée - Medical Master";
    html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6;">
        <h2>Bonjour ${patientName},</h2>
        <p>Votre demande de rendez-vous a été envoyée avec succès.</p>
        <div style="background-color: #d1ecf1; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #0c5460; margin-top: 0;">⏳ Détails du rendez-vous</h3>
          <p><strong>Date:</strong> ${formattedDate}</p>
          <p><strong>Raison:</strong> ${reason}</p>
        </div>
        <p>Vous recevrez une notification dès qu'un infirmier acceptera votre demande.</p>
        <p>Cordialement,<br>L'équipe Medical Master</p>
      </div>
    `;
  }

  await transporter.sendMail({
    from: process.env.EMAIL_USER,
    to,
    subject,
    html,
  });
};

