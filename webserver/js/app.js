const API = '/api/v1';
let state = { token: null, user: null, page: 'login', patients: [], nurses: [], vitals: [], appointments: [], emergencies: [] };
let refreshTimer = null;
let emergencyRefreshTimer = null;
let rtSocket = null;

function connectSocket() {
  if (rtSocket && rtSocket.connected) return;
  if (!state.token) return;
  try {
    rtSocket = io(window.location.origin, { auth: { token: state.token } });
    rtSocket.on('connect', function() { console.log('Socket connected'); });
    rtSocket.on('disconnect', function() { console.log('Socket disconnected'); });
    rtSocket.on('vitals:update', function(data) { loadVitals(); });
    rtSocket.on('emergency:new', function(data) { loadEmergencies(); });
    rtSocket.on('sos:new', function(data) { loadEmergencies(); });
    rtSocket.on('new_message', function(data) { console.log('New message received'); });
  } catch(e) { console.log('Socket init error', e); }
}

function disconnectSocket() {
  if (rtSocket) { rtSocket.disconnect(); rtSocket = null; }
}

function api(path, opts) {
  opts = opts || {};
  var headers = { 'Content-Type': 'application/json' };
  if (state.token) headers['Authorization'] = 'Bearer ' + state.token;
  return fetch(API + path, Object.assign({}, opts, { headers: headers }))
    .then(function(r) { return r.json().catch(function() { return { success: false, message: 'Erreur réseau' }; }); });
}

function show(page, data) { state.page = page; render(data); }

function initials(n) { return (n || 'A').split(' ').map(function(w) { return w[0]; }).filter(Boolean).join('').slice(0, 2).toUpperCase(); }

function ago(d) {
  if (!d) return '\u2014';
  var diff = Date.now() - new Date(d).getTime();
  var m = Math.floor(diff / 60000);
  if (m < 1) return "à l'instant"; if (m < 60) return 'il y a ' + m + 'min';
  var h = Math.floor(m / 60); if (h < 24) return 'il y a ' + h + 'h';
  return new Date(d).toLocaleDateString('fr-FR');
}

function fdate(d) { return d ? new Date(d).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '\u2014'; }

function escapeHtml(s) {
  if (!s) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function modal(title, body, actions) {
  var ov = document.createElement('div'); ov.className = 'modal-overlay active'; ov.id = 'modalOverlay';
  ov.innerHTML = '<div class="modal"><h2>' + title + '</h2>' + body + '<div class="modal-actions">' + actions + '</div></div>';
  document.body.appendChild(ov);
  ov.addEventListener('click', function(e) { if (e.target === ov) ov.remove(); });
  return ov;
}

function confirmDelete(id, name, type) {
  var m = modal(
    'Confirmer la suppression',
    '<p style="color:var(--text-secondary);margin-bottom:8px">Êtes-vous sûr de vouloir supprimer ' + (type === 'patient' ? 'le patient' : "l'infirmier") + ' <strong>' + escapeHtml(name) + '</strong> ?</p><p style="color:var(--danger);font-size:13px">Cette action est irréversible.</p>',
    '<button class="btn btn-sm btn-ghost" onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button> <button class="btn btn-sm btn-soft-danger" id="confirmDelBtn">Supprimer</button>'
  );
  document.getElementById('confirmDelBtn').onclick = async function() {
    var r = await api('/users/' + id, { method: 'DELETE' });
    m.remove();
    if (r.success) { await loadData(); show(type === 'patient' ? 'patients' : 'nurses'); }
    else alert(r.message || 'Erreur');
  };
}

function editModal(userId, type) {
  var u = userId ? state[type === 'patient' ? 'patients' : 'nurses'].find(function(x) { return x._id === userId; }) : null;
  var isP = type === 'patient';
  var bloodOpts = ['A+','A-','B+','B-','AB+','AB-','O+','O-'].map(function(b) { return '<option ' + (u && u.groupeSanguin === b ? 'selected' : '') + '>' + b + '</option>'; }).join('');
  var nurseOpts = '<option value="">— Aucun —</option>' + state.nurses.map(function(n) { return '<option value="' + n._id + '" ' + (u && u.assignedNurse === n._id ? 'selected' : '') + '>' + escapeHtml(n.name) + '</option>'; }).join('');
  var m = modal(
    (u ? 'Modifier' : 'Créer') + ' ' + (isP ? 'un patient' : 'un infirmier'),
    '<form id="userForm"><div style="display:grid;grid-template-columns:1fr 1fr;gap:14px">' +
    (u && isP ? '<div class="form-group" style="grid-column:1/-1"><label>ID Patient (ESP32)</label><input id="fId" value="' + escapeHtml(u._id) + '" readonly style="background:#f3f4f6;color:#374151;cursor:not-allowed;font-family:monospace;font-size:12px;border:1.5px solid var(--border);border-radius:22px;padding:17px 18px;width:100%" title="ID MongoDB"></div>' : '') +
    '<div class="form-group" style="grid-column:1/-1"><label>Nom complet</label><input id="fName" value="' + escapeHtml(u && u.name) + '" required></div>' +
    '<div class="form-group"><label>Email</label><input type="email" id="fEmail" value="' + escapeHtml(u && u.email) + '" ' + (u ? '' : 'required') + '></div>' +
    '<div class="form-group"><label>' + (u ? 'Nouveau mot de passe' : 'Mot de passe') + '</label><input type="password" id="fPass" placeholder="' + (u ? 'Laisser vide' : '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022') + '" ' + (u ? '' : 'required') + '></div>' +
    '<div class="form-group"><label>Téléphone</label><input id="fPhone" value="' + escapeHtml(u && u.phone) + '" required pattern="0[567][0-9]{8}" title="06/07/05 suivi de 8 chiffres"></div>' +
    (isP ? '<div class="form-group"><label>Groupe sanguin</label><select id="fBlood">' + bloodOpts + '</select></div><div class="form-group"><label>Infirmier</label><select id="fNurse">' + nurseOpts + '</select></div>' : '') +
    '</div><div id="formError" class="error-msg" style="display:none;margin-top:8px"></div></form>',
    '<button class="btn btn-sm btn-ghost" onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button> <button class="btn btn-sm btn-primary" id="formSubmitBtn" style="width:auto">' + (u ? 'Enregistrer' : 'Créer') + '</button>'
  );
  document.getElementById('formSubmitBtn').onclick = async function() {
    var data = {
      name: document.getElementById('fName').value,
      email: document.getElementById('fEmail').value,
      phone: document.getElementById('fPhone').value,
    };
    var pass = document.getElementById('fPass').value;
    if (pass) data.password = pass;
    if (isP) {
      data.role = 'patient';
      data.groupeSanguin = document.getElementById('fBlood').value;
      data.assignedNurse = document.getElementById('fNurse').value || null;
    } else data.role = 'nurse';
    var url = u ? '/users/' + userId : '/users/create';
    var method = u ? 'PUT' : 'POST';
    var r = await api(url, { method: method, body: JSON.stringify(data) });
    if (r.success) { m.remove(); await loadData(); show(type === 'patient' ? 'patients' : 'nurses'); }
    else { var el = document.getElementById('formError'); el.textContent = r.message || 'Erreur'; el.style.display = 'block'; }
  };
}

// ===== VIEWS =====
function loginView() {
  return '<div class="login-page">' +
    '<div class="login-card">' +
      '<div class="logo-wrap">🏥</div>' +
      '<h1>Medical Master</h1>' +
      '<p class="subtitle">Connectez-vous à votre espace</p>' +
      '<form id="loginForm">' +
        '<div class="form-group"><label>Email</label><input type="email" id="email" placeholder="admin@medical-master.com" required></div>' +
        '<div class="form-group"><label>Mot de passe</label><input type="password" id="password" placeholder="••••••••" required></div>' +
        '<button type="submit" class="btn btn-primary" id="loginBtn">Se connecter</button>' +
        '<div id="loginError" class="error-msg"></div>' +
        '<div id="loginLoading" class="loading-msg">Connexion en cours…</div>' +
      '</form>' +
    '</div>' +
  '</div>';
}

function renderShell(page) {
  var items = [
    { s: 'Général' }, { id: 'dashboard', i: '📊', l: 'Tableau de bord' },
    { s: 'Gestion' }, { id: 'patients', i: '👥', l: 'Patients', c: state.patients.length },
    { id: 'nurses', i: '👨‍⚕️', l: 'Infirmiers', c: state.nurses.length },
    { s: 'Monitoring' }, { id: 'vitals', i: '❤️', l: 'Signes vitaux' },
    { id: 'emergencies', i: '🚨', l: 'Urgences' },
    { s: 'Planning' }, { id: 'appointments', i: '📅', l: 'Rendez-vous' },
  ];
  var nav = '';
  var topTitle = '';
  for (var i = 0; i < items.length; i++) {
    var x = items[i];
    if (x.s) {
      nav += '<div class="section-label">' + x.s + '</div>';
    } else {
      nav += '<a class="' + (page === x.id ? 'active' : '') + '" onclick="navTo(\'' + x.id + '\')"><span class="nav-icon">' + x.i + '</span> ' + x.l + (x.c !== undefined ? '<span class="nav-badge">' + x.c + '</span>' : '') + '</a>';
    }
    if (x.id === page) topTitle = x.l;
  }
  return '<div class="sidebar">' +
    '<div class="sidebar-header">' +
      '<div class="brand"><span class="brand-icon">🏥</span><span class="brand-text">Medical Master</span></div>' +
      '<div class="brand-version">Administrateur</div>' +
    '</div>' +
    '<div class="sidebar-nav">' + nav + '</div>' +
    '<div class="sidebar-footer">' +
      '<div class="user-card" onclick="logout()">' +
        '<span class="avatar">' + initials(state.user && state.user.name) + '</span>' +
        '<div><div class="user-name">' + (escapeHtml(state.user && state.user.name) || 'Admin') + '</div><div class="user-role">Déconnexion</div></div>' +
      '</div>' +
    '</div>' +
  '</div>' +
  '<div class="main">' +
    '<div class="topbar">' +
      '<h1>' + topTitle + '</h1>' +
      '<div class="topbar-right"><span class="time">' + new Date().toLocaleString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) + '</span></div>' +
    '</div>' +
    '<div class="content" id="pageContent"></div>' +
  '</div>';
}

function dashboardView() {
  try {
    var ae = state.emergencies.filter(function(e) { return e.status !== 'resolved' && e.status !== 'cancelled'; }).length;
    var av = state.vitals.filter(function(v) { var hr = v.heartRate; return hr && (hr.value !== undefined ? hr.value > 0 : hr > 0); }).length;
    var pa = state.appointments.filter(function(a) { return a.status === 'pending'; }).length;

    var html = '<div class="stats-grid">';
    html += '<div class="card stat-card"><div class="stat-icon-wrap teal">👥</div><h3>Patients</h3><div class="value">' + state.patients.length + '</div><div class="sub">' + av + ' avec données actives</div></div>';
    html += '<div class="card stat-card"><div class="stat-icon-wrap blue">👨‍⚕️</div><h3>Infirmiers</h3><div class="value">' + state.nurses.length + '</div><div class="sub">personnel soignant</div></div>';
    html += '<div class="card stat-card"><div class="stat-icon-wrap amber">📅</div><h3>Rendez-vous</h3><div class="value">' + state.appointments.length + '</div><div class="sub">' + pa + ' en attente</div></div>';
    html += '<div class="card stat-card"><div class="stat-icon-wrap red">🚨</div><h3>Urgences</h3><div class="value" style="color:' + (ae > 0 ? 'var(--danger)' : 'var(--success)') + '">' + ae + '</div><div class="sub">' + (ae > 0 ? 'actives' : 'aucune urgence') + '</div></div>';
    html += '</div>';

    html += '<div class="grid-2">';

    // Vitals table
    html += '<div class="card"><div class="card-header"><h2>❤️ Derniers signes vitaux</h2><button class="btn btn-sm btn-ghost" onclick="loadVitals();show(\'dashboard\')">↻</button></div>';
    html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>FC</th><th>SpO₂</th><th>Temp</th><th>Heure</th></tr></thead><tbody>';
    if (state.vitals.length === 0) {
      html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">📊</div><p>Aucune donnée</p></div></td></tr>';
    } else {
      var vitalsSlice = state.vitals.slice(0, 6);
      for (var i = 0; i < vitalsSlice.length; i++) {
        var v = vitalsSlice[i];
        var p = null;
        for (var j = 0; j < state.patients.length; j++) {
          if (state.patients[j]._id === v.patientId) { p = state.patients[j]; break; }
        }
        var hr = (v.heartRate && v.heartRate.value !== undefined) ? v.heartRate.value : (v.heartRate || 0);
        var s = (v.oxygenLevel && v.oxygenLevel.value !== undefined) ? v.oxygenLevel.value : (v.oxygenLevel || 0);
        var hrClass = (hr > 100 || (hr > 0 && hr < 50)) ? 'badge-danger' : hr > 0 ? 'badge-success' : 'badge-gray';
        var sClass = s > 0 && s < 90 ? 'badge-danger' : s > 0 ? 'badge-success' : 'badge-gray';
        var tempStr = (v.temperature && v.temperature.value) ? v.temperature.value.toFixed(1) + '°C' : '—';
        var pName = escapeHtml(v.patientName || (p && p.name)) || 'Inconnu';
        html += '<tr><td><strong>' + pName + '</strong></td><td><span class="badge ' + hrClass + '">' + (hr || '—') + '</span></td><td><span class="badge ' + sClass + '">' + (s || '—') + '%</span></td><td><span class="td-sub">' + tempStr + '</span></td><td><span class="td-sub">' + ago(v.measuredAt) + '</span></td></tr>';
      }
    }
    html += '</tbody></table></div></div>';

    // Emergencies table
    html += '<div class="card"><div class="card-header"><h2>🚨 Urgences actives</h2></div>';
    html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>Type</th><th>Statut</th><th>Heure</th></tr></thead><tbody>';
    if (state.emergencies.length === 0) {
      html += '<tr><td colspan="4"><div class="empty-state"><div class="empty-icon">✅</div><p>Aucune urgence</p></div></td></tr>';
    } else {
      var emerSlice = state.emergencies.slice(0, 5);
      for (var k = 0; k < emerSlice.length; k++) {
        var e = emerSlice[k];
        var ep = null;
        for (var l = 0; l < state.patients.length; l++) {
          if (state.patients[l]._id === e.patientId) { ep = state.patients[l]; break; }
        }
        var actif = e.status !== 'resolved' && e.status !== 'cancelled';
        html += '<tr><td><strong>' + (escapeHtml(ep && ep.name) || 'Inconnu') + '</strong></td>';
        html += '<td><span class="badge ' + (e.type === 'sos' ? 'badge-danger' : 'badge-warning') + '">' + (e.type || 'SOS') + '</span></td>';
        html += '<td><span class="badge ' + (actif ? 'badge-danger' : 'badge-gray') + '">' + (e.status === 'active' ? 'Active' : e.status === 'resolved' ? 'Résolue' : e.status || 'inconnu') + '</span></td>';
        html += '<td><span class="td-sub">' + ago(e.createdAt) + '</span></td>';
      html += '<td><button class="btn-icon" onclick="deleteEmergency(\'' + e._id + '\')">🗑️</button></td></tr>';
      }
    }
    html += '</tbody></table></div></div>';
    html += '</div>';

    // Appointments table
    html += '<div class="card"><div class="card-header"><h2>📅 Prochains rendez-vous</h2></div>';
    html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>Infirmier</th><th>Date</th><th>Motif</th><th>Statut</th></tr></thead><tbody>';
    if (state.appointments.length === 0) {
      html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">📅</div><p>Aucun rendez-vous</p></div></td></tr>';
    } else {
      var apptSlice = state.appointments.slice(0, 6);
      for (var m = 0; m < apptSlice.length; m++) {
        var a = apptSlice[m];
        var pid = typeof a.patientId === 'object' ? (a.patientId._id || a.patientId) : a.patientId;
        var nid = typeof a.nurseId === 'object' ? (a.nurseId._id || a.nurseId) : a.nurseId;
        var ap = null;
        for (var n = 0; n < state.patients.length; n++) {
          if (state.patients[n]._id === pid) { ap = state.patients[n]; break; }
        }
        var an = null;
        for (var o = 0; o < state.nurses.length; o++) {
          if (state.nurses[o]._id === nid) { an = state.nurses[o]; break; }
        }
        var aStatus = a.status === 'accepted' ? 'Accepté' : a.status === 'pending' ? 'En attente' : a.status === 'cancelled' ? 'Annulé' : (a.status || 'en attente');
        var aClass = a.status === 'accepted' ? 'badge-success' : a.status === 'pending' ? 'badge-warning' : a.status === 'cancelled' ? 'badge-danger' : 'badge-info';
        html += '<tr><td><strong>' + (escapeHtml(ap && ap.name) || (a.patientId && a.patientId.name) || 'Inconnu') + '</strong></td>';
        html += '<td><span class="td-sub">' + (escapeHtml(an && an.name) || (a.nurseId && a.nurseId.name) || '—') + '</span></td>';
        html += '<td><span class="td-sub">' + fdate(a.dateTime || a.appointmentDate) + '</span></td>';
        html += '<td><span class="td-sub">' + (escapeHtml(a.reason) || '—') + '</span></td>';
        html += '<td><span class="badge ' + aClass + '">' + aStatus + '</span></td></tr>';
      }
    }
    html += '</tbody></table></div></div>';

    return html;
  } catch(err) {
    console.error('Dashboard render error:', err);
    return '<div class="card"><div class="card-body"><div class="empty-state"><div class="empty-icon">⚠️</div><p>Erreur de chargement du tableau de bord</p><p style="font-size:12px;color:var(--text-muted);margin-top:8px">' + escapeHtml(err.message) + '</p></div></div></div>';
  }
}

function patientsView() {
  var html = '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px">';
  html += '<h2 style="font-size:18px;font-weight:700">👥 Patients <span style="color:var(--text-muted);font-weight:500;font-size:14px">(' + state.patients.length + ')</span></h2>';
  html += '<button class="btn btn-sm btn-primary" onclick="editModal(null,\'patient\')" style="width:auto">➕ Nouveau patient</button>';
  html += '</div><div class="card"><div class="card-body"><table>';
  html += '<thead><tr><th>ID</th><th>Nom</th><th>Contact</th><th>Sang</th><th>Statut</th><th>FC</th><th style="width:130px">Actions</th></tr></thead><tbody>';
  if (state.patients.length === 0) {
    html += '<tr><td colspan="7"><div class="empty-state"><div class="empty-icon">👥</div><p>Aucun patient</p></div></td></tr>';
  } else {
    for (var i = 0; i < state.patients.length; i++) {
      var p = state.patients[i];
      var v = null;
      for (var j = 0; j < state.vitals.length; j++) {
        if (state.vitals[j].patientId === p._id) { v = state.vitals[j]; break; }
      }
      var hr = (v && v.heartRate && v.heartRate.value) || 0;
      html += '<tr>';
      html += '<td><span class="td-sub" style="font-family:monospace;font-size:11px">' + escapeHtml(p._id) + '</span></td>';
      html += '<td><strong>' + escapeHtml(p.name) + '</strong></td>';
      html += '<td><span class="td-sub">' + escapeHtml(p.email) + '<br>' + escapeHtml(p.phone) + '</span></td>';
      html += '<td><span class="badge badge-info">' + (p.groupeSanguin || '—') + '</span></td>';
      html += '<td><span class="badge ' + (p.isVerified ? 'badge-success' : 'badge-warning') + '">' + (p.isVerified ? 'Actif' : 'En attente') + '</span></td>';
      html += '<td><span class="badge ' + (hr > 0 ? 'badge-info' : 'badge-gray') + '">' + (hr > 0 ? hr + ' bpm' : '—') + '</span></td>';
      html += '<td>';
      html += '<button class="btn btn-xs btn-soft-accent" onclick="showPatientVitals(\'' + p._id + '\')" title="Voir les signes vitaux">❤️</button> ';
      html += '<button class="btn btn-xs btn-ghost" onclick="editModal(\'' + p._id + '\',\'patient\')" title="Modifier">✏️</button> ';
      html += '<button class="btn btn-xs btn-soft-danger" onclick="confirmDelete(\'' + p._id + '\',\'' + escapeHtml(p.name) + '\',\'patient\')" title="Supprimer">🗑️</button>';
      html += '</td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function nursesView() {
  var html = '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px">';
  html += '<h2 style="font-size:18px;font-weight:700">👨‍⚕️ Infirmiers <span style="color:var(--text-muted);font-weight:500;font-size:14px">(' + state.nurses.length + ')</span></h2>';
  html += '<button class="btn btn-sm btn-primary" onclick="editModal(null,\'nurse\')" style="width:auto">➕ Nouvel infirmier</button>';
  html += '</div><div class="card"><div class="card-body"><table>';
  html += '<thead><tr><th>Nom</th><th>Contact</th><th>Patients</th><th style="width:90px">Actions</th></tr></thead><tbody>';
  if (state.nurses.length === 0) {
    html += '<tr><td colspan="4"><div class="empty-state"><div class="empty-icon">👨‍⚕️</div><p>Aucun infirmier</p></div></td></tr>';
  } else {
    for (var i = 0; i < state.nurses.length; i++) {
      var n = state.nurses[i];
      var cnt = 0;
      for (var j = 0; j < state.patients.length; j++) {
        if (state.patients[j].assignedNurse === n._id) cnt++;
      }
      html += '<tr>';
      html += '<td><strong>' + escapeHtml(n.name) + '</strong></td>';
      html += '<td><span class="td-sub">' + escapeHtml(n.email) + '<br>' + escapeHtml(n.phone) + '</span></td>';
      html += '<td><span class="badge badge-info">' + cnt + ' patient' + (cnt > 1 ? 's' : '') + '</span></td>';
      html += '<td>';
      html += '<button class="btn btn-xs btn-ghost" onclick="editModal(\'' + n._id + '\',\'nurse\')" title="Modifier">✏️</button> ';
      html += '<button class="btn btn-xs btn-soft-danger" onclick="confirmDelete(\'' + n._id + '\',\'' + escapeHtml(n.name) + '\',\'nurse\')" title="Supprimer">🗑️</button>';
      html += '</td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function vitalsView() {
  var html = '<div class="card"><div class="card-header"><h2>❤️ Signes vitaux en direct</h2><button class="btn btn-sm btn-soft-accent" onclick="loadVitals();show(\'vitals\')">↻ Actualiser</button></div>';
  html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>FC</th><th>SpO₂</th><th>Température</th><th>Source</th><th>Mesuré</th></tr></thead><tbody>';
  if (state.vitals.length === 0) {
    html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">📊</div><p>Aucune donnée</p></div></td></tr>';
  } else {
    for (var i = 0; i < state.vitals.length; i++) {
      var v = state.vitals[i];
      var hr = (v.heartRate && v.heartRate.value !== undefined) ? v.heartRate.value : (v.heartRate || 0);
      var s = (v.oxygenLevel && v.oxygenLevel.value !== undefined) ? v.oxygenLevel.value : (v.oxygenLevel || 0);
      var hrClass = (hr > 100 || (hr > 0 && hr < 50)) ? 'badge-danger' : hr > 0 ? 'badge-success' : 'badge-gray';
      var sClass = s > 0 && s < 90 ? 'badge-danger' : s > 0 ? 'badge-success' : 'badge-gray';
      html += '<tr><td><strong>' + (escapeHtml(v.patientName) || 'Inconnu') + '</strong></td>';
      html += '<td><span class="badge ' + hrClass + '">' + (hr > 0 ? hr + ' bpm' : '—') + '</span></td>';
      html += '<td><span class="badge ' + sClass + '">' + (s > 0 ? s + '%' : '—') + '</span></td>';
      html += '<td><span class="td-sub">' + ((v.temperature && v.temperature.value) ? v.temperature.value.toFixed(1) + '°C' : '—') + '</span></td>';
      html += '<td><span class="badge badge-info">' + (v.source || 'manuel') + '</span></td>';
      html += '<td><span class="td-sub">' + ago(v.measuredAt) + '</span></td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function appointmentsView() {
  var html = '<div class="card"><div class="card-header"><h2>📅 Rendez-vous <span class="h2-sub">(' + state.appointments.length + ')</span></h2></div>';
  html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>Infirmier</th><th>Date</th><th>Motif</th><th>Statut</th></tr></thead><tbody>';
  if (state.appointments.length === 0) {
    html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">📅</div><p>Aucun rendez-vous</p></div></td></tr>';
  } else {
    for (var i = 0; i < state.appointments.length; i++) {
      var a = state.appointments[i];
      var pid = typeof a.patientId === 'object' ? (a.patientId._id || a.patientId) : a.patientId;
      var nid = typeof a.nurseId === 'object' ? (a.nurseId._id || a.nurseId) : a.nurseId;
      var ap = null;
      for (var j = 0; j < state.patients.length; j++) {
        if (state.patients[j]._id === pid) { ap = state.patients[j]; break; }
      }
      var an = null;
      for (var k = 0; k < state.nurses.length; k++) {
        if (state.nurses[k]._id === nid) { an = state.nurses[k]; break; }
      }
      var aStatus = a.status === 'accepted' ? 'Accepté' : a.status === 'pending' ? 'En attente' : a.status === 'cancelled' ? 'Annulé' : (a.status || 'en attente');
      var aClass = a.status === 'accepted' ? 'badge-success' : a.status === 'pending' ? 'badge-warning' : a.status === 'cancelled' ? 'badge-danger' : 'badge-info';
      html += '<tr><td><strong>' + (escapeHtml(ap && ap.name) || (a.patientId && a.patientId.name) || 'Inconnu') + '</strong></td>';
      html += '<td><span class="td-sub">' + (escapeHtml(an && an.name) || (a.nurseId && a.nurseId.name) || '—') + '</span></td>';
      html += '<td><span class="td-sub">' + fdate(a.dateTime || a.appointmentDate) + '</span></td>';
      html += '<td><span class="td-sub">' + (escapeHtml(a.reason) || '—') + '</span></td>';
      html += '<td><span class="badge ' + aClass + '">' + aStatus + '</span></td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function emergenciesView() {
  var actifs = state.emergencies.filter(function(e) { return e.status !== 'resolved' && e.status !== 'cancelled'; }).length;
  var html = '<div class="card"><div class="card-header"><h2>🚨 Alertes d\'urgence</h2><span class="badge ' + (actifs > 0 ? 'badge-danger' : 'badge-success') + '">' + (actifs > 0 ? actifs + ' active(s)' : 'Aucune urgence') + '</span></div>';
  html += '<div class="card-body"><table><thead><tr><th>Patient</th><th>Type</th><th>Localisation</th><th>Statut</th><th>Signalé</th><th>Action</th></tr></thead><tbody>';
  if (state.emergencies.length === 0) {
    html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">✅</div><p>Aucune urgence</p></div></td></tr>';
  } else {
    for (var i = 0; i < state.emergencies.length; i++) {
      var e = state.emergencies[i];
      var p = null;
      for (var j = 0; j < state.patients.length; j++) {
        if (state.patients[j]._id === e.patientId) { p = state.patients[j]; break; }
      }
      var actif = e.status !== 'resolved' && e.status !== 'cancelled';
      var eType = e.type === 'sos' ? 'SOS' : e.type === 'fall' ? 'Chute' : e.type === 'vitals_critical' ? 'Critique' : (e.type || 'SOS');
      var eStatus = e.status === 'active' ? 'Active' : e.status === 'resolved' ? 'Résolue' : e.status === 'cancelled' ? 'Annulée' : (e.status || 'inconnu');
      var loc = e.location && e.location.lat ? (e.location.lat.toFixed(4) + ', ' + e.location.lng.toFixed(4)) : '—';
      html += '<tr><td><strong>' + (escapeHtml(p && p.name) || 'Inconnu') + '</strong></td>';
      html += '<td><span class="badge badge-danger">' + eType + '</span></td>';
      html += '<td><span class="td-sub">' + loc + '</span></td>';
      html += '<td><span class="badge ' + (actif ? 'badge-danger' : 'badge-gray') + '">' + eStatus + '</span></td>';
      html += '<td><span class="td-sub">' + ago(e.createdAt) + '</span></td>';
      html += '<td><button class="btn-icon" onclick="deleteEmergency(\'' + e._id + '\')">🗑️</button></td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function patientVitalsView(id) {
  var p = null;
  for (var i = 0; i < state.patients.length; i++) {
    if (state.patients[i]._id === id) { p = state.patients[i]; break; }
  }
  if (!p) p = { name: 'Patient' };
  var all = [];
  for (var j = 0; j < state.vitals.length; j++) {
    if (state.vitals[j].patientId === id) all.push(state.vitals[j]);
  }
  all.sort(function(a, b) { return new Date(b.measuredAt) - new Date(a.measuredAt); });
  var l = all[0] || {};
  var hr = (l.heartRate && l.heartRate.value !== undefined) ? l.heartRate.value : (l.heartRate || 0);
  var spo2 = (l.oxygenLevel && l.oxygenLevel.value !== undefined) ? l.oxygenLevel.value : (l.oxygenLevel || 0);
  var temp = (l.temperature && l.temperature.value !== undefined) ? l.temperature.value : (l.temperature || 0);

  var hrColor = (hr > 100 || (hr > 0 && hr < 50)) ? 'var(--danger)' : hr > 0 ? 'var(--success)' : 'var(--text-muted)';
  var hrStatus = (hr > 100 || (hr > 0 && hr < 50)) ? '⚠ Anormal' : hr > 0 ? '● Normal' : '—';
  var spColor = spo2 > 0 && spo2 < 90 ? 'var(--danger)' : spo2 > 0 ? 'var(--success)' : 'var(--text-muted)';
  var spStatus = spo2 > 0 && spo2 < 90 ? '⚠ Bas' : spo2 > 0 ? '● Normal' : '—';
  var tColor = temp >= 38 ? 'var(--danger)' : temp > 0 ? 'var(--success)' : 'var(--text-muted)';
  var tStatus = temp >= 38 ? '⚠ Fièvre' : temp > 0 ? '● Normal' : '—';

  var html = '<div style="margin-bottom:20px;display:flex;align-items:center;gap:12px">';
  html += '<button class="btn btn-sm btn-ghost" onclick="show(\'patients\')">← Retour</button>';
  html += '<h2 style="font-size:18px;font-weight:700">' + escapeHtml(p.name) + ' — Signes vitaux</h2>';
  html += '<span class="td-sub" style="font-family:monospace;font-size:12px;color:var(--text-muted)">' + escapeHtml(p._id) + '</span></div>';

  html += '<div class="vital-grid">';
  html += '<div class="card vital-card"><div class="v-label">FC</div><div class="v-value">' + (hr || '—') + '</div><div class="v-unit">bpm</div><div class="v-status" style="color:' + hrColor + '">' + hrStatus + '</div></div>';
  html += '<div class="card vital-card"><div class="v-label">SpO₂</div><div class="v-value">' + (spo2 || '—') + '</div><div class="v-unit">%</div><div class="v-status" style="color:' + spColor + '">' + spStatus + '</div></div>';
  html += '<div class="card vital-card"><div class="v-label">Température</div><div class="v-value">' + (temp > 0 ? temp.toFixed(1) : '—') + '</div><div class="v-unit">°C</div><div class="v-status" style="color:' + tColor + '">' + tStatus + '</div></div>';
  html += '</div>';

  html += '<div class="card"><div class="card-header"><h2>📊 Historique <span class="h2-sub">(' + all.length + ' relevés)</span></h2></div>';
  html += '<div class="card-body"><table><thead><tr><th>FC</th><th>SpO₂</th><th>Température</th><th>Source</th><th>Date</th></tr></thead><tbody>';
  if (all.length === 0) {
    html += '<tr><td colspan="6"><div class="empty-state"><div class="empty-icon">📊</div><p>Aucune donnée</p></div></td></tr>';
  } else {
    for (var k = 0; k < all.length; k++) {
      var v = all[k];
      var vhr = (v.heartRate && v.heartRate.value) || 0;
      var vhrClass = vhr > 100 ? 'badge-danger' : vhr > 0 ? 'badge-success' : 'badge-gray';
      html += '<tr><td><span class="badge ' + vhrClass + '">' + (vhr || '—') + ' bpm</span></td>';
      html += '<td>' + ((v.oxygenLevel && v.oxygenLevel.value) || '—') + '%</td>';
      html += '<td><span class="td-sub">' + ((v.temperature && v.temperature.value) ? v.temperature.value.toFixed(1) + '°C' : '—') + '</span></td>';
      html += '<td><span class="badge badge-info">' + (v.source || 'manuel') + '</span></td>';
      html += '<td><span class="td-sub">' + fdate(v.measuredAt) + '</span></td></tr>';
    }
  }
  html += '</tbody></table></div></div>';
  return html;
}

function render(data) {
  var el = document.getElementById('app');
  if (state.page === 'login') {
    el.innerHTML = loginView();
    var form = document.getElementById('loginForm');
    if (form) form.addEventListener('submit', handleLogin);
    return;
  }
  el.innerHTML = renderShell(state.page);
  var pc = document.getElementById('pageContent');
  if (!pc) return;
  switch (state.page) {
    case 'dashboard': pc.innerHTML = dashboardView(); break;
    case 'patients': pc.innerHTML = patientsView(); break;
    case 'nurses': pc.innerHTML = nursesView(); break;
    case 'vitals': pc.innerHTML = vitalsView(); break;
    case 'appointments': pc.innerHTML = appointmentsView(); break;
    case 'emergencies': pc.innerHTML = emergenciesView(); break;
    case 'patient-vitals': pc.innerHTML = patientVitalsView(data); break;
    default: pc.innerHTML = '<div class="empty-state"><div class="empty-icon">🔄</div><p>Page inconnue</p></div>';
  }
}

function navTo(page) { show(page); }

async function handleLogin(e) {
  e.preventDefault();
  var email = document.getElementById('email').value;
  var password = document.getElementById('password').value;
  var btn = document.getElementById('loginBtn');
  var err = document.getElementById('loginError');
  var load = document.getElementById('loginLoading');
  err.style.display = 'none'; load.style.display = 'block'; btn.disabled = true;
  try {
    var res = await api('/auth/login', { method: 'POST', body: JSON.stringify({ email: email, password: password }) });
    if (res.success && res.token) {
      state.token = res.token; state.user = res.user || { name: email.split('@')[0], email: email };
      localStorage.setItem('token', state.token); localStorage.setItem('user', JSON.stringify(state.user));
      await loadData(); show('dashboard');
      if (refreshTimer) clearInterval(refreshTimer);
      refreshTimer = setInterval(loadVitals, 10000);
      if (emergencyRefreshTimer) clearInterval(emergencyRefreshTimer);
      emergencyRefreshTimer = setInterval(function() { loadEmergencies(); }, 15000);
      connectSocket();
    } else { err.textContent = res.message || 'Identifiants invalides'; err.style.display = 'block'; }
  } catch (e) { err.textContent = 'Erreur de connexion'; err.style.display = 'block'; }
  load.style.display = 'none'; btn.disabled = false;
}

function logout() {
  state.token = null; state.user = null;
  localStorage.removeItem('token'); localStorage.removeItem('user');
  if (refreshTimer) clearInterval(refreshTimer);
  if (emergencyRefreshTimer) clearInterval(emergencyRefreshTimer);
  disconnectSocket();
  show('login');
}

async function showPatientVitals(id) { await loadVitals(); show('patient-vitals', id); }

async function loadPatients() { try { var r = await api('/users?role=patient'); if (r.success) state.patients = r.data || []; } catch(e) { console.error('loadPatients:', e); } }
async function deleteEmergency(id) {
  if (!confirm("Supprimer cette alerte d'urgence ?")) return;
  try {
    var r = await api("/emergency/" + id, { method: "DELETE" });
    if (r.success) {
      await loadEmergencies();
      show("emergencies");
    } else {
      alert(r.message || "Erreur de suppression");
    }
  } catch(e) { console.error("deleteEmergency:", e); }
}

async function loadNurses() { try { var r = await api('/users?role=nurse'); if (r.success) state.nurses = r.data || []; } catch(e) { console.error('loadNurses:', e); } }
async function loadVitals() {
  try {
    var r = await api('/vitals/all-patients');
    if (r.success) {
      var raw = r.data || [];
      var mapped = [];
      for (var i = 0; i < raw.length; i++) {
        var item = raw[i];
        var lr = item.latestReading || item;
        var patient = item.patient || {};
        mapped.push({
          _id: lr._id,
          patientId: lr.patientId || patient._id,
          patientName: patient.name || lr.patientName || 'Inconnu',
          heartRate: lr.heartRate,
          oxygenLevel: lr.oxygenLevel,
          temperature: lr.temperature,
          measuredAt: lr.measuredAt,
          source: lr.source
        });
      }
      mapped.sort(function(a, b) { return new Date(b.measuredAt || 0) - new Date(a.measuredAt || 0); });
      state.vitals = mapped;
    }
  } catch(e) { console.error('loadVitals:', e); }
}
async function loadAppointments() { try { var r = await api('/appointments/all'); if (r.success) state.appointments = (r.appointments || []).sort(function(a, b) { return new Date(b.dateTime || b.appointmentDate) - new Date(a.dateTime || a.appointmentDate); }); } catch(e) { console.error('loadAppointments:', e); } }
async function loadEmergencies() { try { var r = await api('/emergency/active'); if (r.success) state.emergencies = r.data || r.emergencies || []; } catch(e) { console.error('loadEmergencies:', e); } }
async function loadData() { await Promise.allSettled([loadPatients(), loadNurses(), loadVitals(), loadAppointments(), loadEmergencies()]); }

(async function init() {
  var saved = localStorage.getItem('token');
  if (saved) {
    state.token = saved;
    try { state.user = JSON.parse(localStorage.getItem('user') || '{}'); } catch(e) {}
    try {
      await loadData();
      show('dashboard');
      refreshTimer = setInterval(loadVitals, 10000);
      emergencyRefreshTimer = setInterval(function() { loadEmergencies(); }, 15000);
      connectSocket();
      return;
    } catch(e) { console.error('Auto-login error:', e); state.token = null; }
  }
  show('login');
})();
