module.exports = {
  apps: [{
    name: "medical-master",
    script: "server.js",
    cwd: "/var/www/webserver/backend",
    env: {
      NODE_ENV: "production"
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "/var/log/pm2-medical-error.log",
    out_file: "/var/log/pm2-medical-out.log",
    max_memory_restart: "500M",
    autorestart: true
  }]
};
