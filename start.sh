#!/bin/bash
# Medical Master - Start/Stop/Restart all services
# Usage: ./start.sh [start|stop|restart|status]

ACTION="${1:-start}"
LOG_FILE="/var/www/startup.log"

log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

stop_services() {
  log "Stopping all services..."

  log "Stopping PM2 processes..."
  pm2 stop all 2>/dev/null && log "PM2 processes stopped" || log "No PM2 processes running"

  log "Stopping Nginx..."
  nginx -s stop 2>/dev/null
  sleep 1
  log "Nginx stopped"

  log "Stopping MongoDB..."
  mongod --shutdown 2>/dev/null
  sleep 2
  log "MongoDB stopped"

  log "All services stopped"
}

start_services() {
  log "============================================"
  log "Starting all services..."

  # 1. MongoDB
  log "Starting MongoDB..."
  if mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
    log "MongoDB already running"
  else
    mongod --dbpath /data/db --fork --logpath /var/log/mongod.log 2>&1 >> "$LOG_FILE"
    sleep 2
    if mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
      log "MongoDB started"
    else
      log "ERROR: MongoDB failed to start"
    fi
  fi

  # 2. Nginx
  log "Starting Nginx..."
  if pgrep -x nginx > /dev/null 2>&1; then
    log "Nginx already running"
  else
    nginx 2>&1 >> "$LOG_FILE"
    sleep 1
    if pgrep -x nginx > /dev/null 2>&1; then
      log "Nginx started"
    else
      log "ERROR: Nginx failed to start"
    fi
  fi

  # 3. PM2 (backend + cloudflare tunnel)
  log "Starting PM2 processes..."
  pm2 resurrect 2>&1 >> "$LOG_FILE" 2>&1 >> "$LOG_FILE"
  sleep 2
  ONLINE=$(pm2 list 2>/dev/null | grep -c "online")
  if [ "$ONLINE" -eq 0 ]; then
    log "No saved PM2 processes, starting from ecosystem config..."
    pm2 start /var/www/webserver/ecosystem.config.cjs 2>&1 >> "$LOG_FILE"
    sleep 3
    ONLINE=$(pm2 list 2>/dev/null | grep -c "online")
  fi
  pm2 save 2>&1 >> "$LOG_FILE"

  # Verify cloudflare tunnel is running
  if ! pm2 list 2>/dev/null | grep -q "cloudflare-tunnel.*online"; then
    log "WARNING: Cloudflare tunnel not online, restarting..."
    pm2 restart cloudflare-tunnel 2>&1 >> "$LOG_FILE"
    sleep 3
  fi

  if [ "$ONLINE" -ge 1 ]; then
    log "PM2 processes started ($ONLINE online)"
  else
    log "WARNING: No PM2 processes are online"
  fi

  log "============================================"
  log "All services started successfully"
  pm2 list 2>&1 | tee -a "$LOG_FILE"
  echo "============================================" >> "$LOG_FILE"
}

status_services() {
  echo ""
  echo "=== Service Status ==="

  echo -n "MongoDB:        "
  if mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then echo "RUNNING"; else echo "STOPPED"; fi

  echo -n "Nginx:          "
  if pgrep -x nginx > /dev/null 2>&1; then echo "RUNNING"; else echo "STOPPED"; fi

  echo ""
  pm2 list 2>/dev/null

  echo -n "Backend API:    "
  if curl -s http://localhost:5000/ > /dev/null 2>&1; then echo "RESPONDING on :5000"; else echo "NOT RESPONDING"; fi

  echo -n "Nginx proxy:    "
  if curl -s http://localhost/api/ > /dev/null 2>&1; then echo "RESPONDING on :80"; else echo "NOT RESPONDING"; fi

  echo -n "Cloudflare:     "
  if pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then echo "RUNNING"; else echo "STOPPED"; fi
}

force_restart() {
  log "============================================"
  log "FORCE RESTARTING ALL SERVICES..."

  # 1. Stop PM2
  log "Stopping PM2 processes..."
  pm2 stop all 2>/dev/null
  pm2 delete all 2>/dev/null
  log "PM2 processes cleared"

  # 2. Stop Nginx
  log "Stopping Nginx..."
  nginx -s stop 2>/dev/null
  pkill -9 nginx 2>/dev/null
  sleep 1
  log "Nginx stopped"

  # 3. Stop MongoDB
  log "Stopping MongoDB..."
  mongod --shutdown 2>/dev/null
  pkill -9 mongod 2>/dev/null
  sleep 2
  log "MongoDB stopped"

  log "All services stopped. Starting fresh..."
  sleep 1

  # 4. Start MongoDB
  log "Starting MongoDB..."
  mongod --dbpath /data/db --fork --logpath /var/log/mongod.log 2>&1 >> "$LOG_FILE"
  sleep 3
  if mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
    log "MongoDB started"
  else
    log "ERROR: MongoDB failed to start"
  fi

  # 5. Start Nginx
  log "Starting Nginx..."
  nginx 2>&1 >> "$LOG_FILE"
  sleep 1
  if pgrep -x nginx > /dev/null 2>&1; then
    log "Nginx started"
  else
    log "ERROR: Nginx failed to start"
  fi

  # 6. Start PM2
  log "Starting PM2 processes..."
  pm2 start /var/www/webserver/ecosystem.config.cjs 2>&1 >> "$LOG_FILE"
  sleep 3
  pm2 save 2>&1 >> "$LOG_FILE"

  # Verify cloudflare tunnel is running
  if ! pm2 list 2>/dev/null | grep -q "cloudflare-tunnel.*online"; then
    log "WARNING: Cloudflare tunnel not online, restarting..."
    pm2 restart cloudflare-tunnel 2>&1 >> "$LOG_FILE"
    sleep 3
  fi

  ONLINE=$(pm2 list 2>/dev/null | grep -c "online")
  log "PM2 processes started ($ONLINE online)"

  log "============================================"
  log "All services restarted successfully"
  pm2 list 2>&1 | tee -a "$LOG_FILE"
  echo "============================================" >> "$LOG_FILE"
}

case "$ACTION" in
  stop)
    stop_services
    ;;
  start)
    start_services
    ;;
  restart)
    force_restart
    ;;
  status)
    status_services
    ;;
  *)
    force_restart
    ;;
esac
