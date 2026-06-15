module.exports = {
  apps: [
    {
      name: "medical-master",
      script: "/var/www/webserver/server.js",
      cwd: "/var/www/webserver",
      env: {
        NODE_ENV: "production",
        PORT: 5000
      },
      max_memory_restart: "500M",
      instances: 1,
      autorestart: true,
      watch: false,
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      error_file: "/var/www/webserver/logs/err.log",
      out_file: "/var/www/webserver/logs/out.log"
    },
    {
      name: "cloudflare-tunnel",
      script: "/usr/local/sbin/cloudflared",
      args: "tunnel --config /root/.cloudflared/config.yml run bir",
      autorestart: true,
      watch: false,
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      error_file: "/var/www/webserver/logs/err.log",
      out_file: "/var/www/webserver/logs/out.log"
    }
  ]
};
