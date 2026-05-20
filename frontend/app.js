/* ============================================================
   FitTrack Pro - App Logic (Auth v2 - token based)
   Updates:
     - "My Workouts" list now expands to show every exercise the
       user added (name · sets · reps · weight · minutes).
     - Dates and purchase times rendered in UAE (Asia/Dubai) tz.
   ============================================================ */

const API = '/api';

// ===== Auth check on page load =====
const TOKEN = localStorage.getItem('fittrack_token');
if (!TOKEN) {
  // No token → kick to login
  window.location.href = '/';
}

// ===== API helper that includes the token =====
async function api(path, options = {}) {
  const res = await fetch(API + path, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + TOKEN,
      ...(options.headers || {})
    },
    body: options.body
  });

  if (res.status === 401) {
    // Token expired or invalid
    localStorage.clear();
    window.location.href = '/';
    throw new Error('Not authenticated');
  }

  return res.json();
}

let exercisesCache = [];
let categoriesCache = [];
let musclesCache = [];

// ===== UAE time helpers (Asia/Dubai · UTC+4 · no DST) =====
const UAE_TZ = 'Asia/Dubai';

function fmtDateUAE(input) {
  // Accepts a YYYY-MM-DD string OR an ISO datetime; renders as
  // "Fri, 24 Apr 2026" in UAE local time.
  if (!input) return '—';
  const d = (typeof input === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(input))
    ? new Date(input + 'T00:00:00+04:00')   // pin date-only to UAE midnight
    : new Date(input);
  return d.toLocaleDateString('en-GB', {
    weekday: 'short', day: '2-digit', month: 'short', year: 'numeric',
    timeZone: UAE_TZ
  });
}

function fmtDateTimeUAE(input) {
  // Renders "24 Apr 2026, 09:23 GST" in UAE time.
  if (!input) return '—';
  const d = new Date(input);
  const datePart = d.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', timeZone: UAE_TZ
  });
  const timePart = d.toLocaleTimeString('en-GB', {
    hour: '2-digit', minute: '2-digit', hour12: false, timeZone: UAE_TZ
  });
  return `${datePart}, ${timePart} GST`;
}

// ===== Toast =====
function toast(msg, isError = false) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast show' + (isError ? ' error' : '');
  setTimeout(() => t.classList.remove('show'), 3000);
}

// ===== Modal helpers =====
function openModal(id) { document.getElementById(id).classList.add('active'); }
function closeModal(id){ document.getElementById(id).classList.remove('active'); }
window.onclick = (e) => {
  if (e.target.classList.contains('modal')) e.target.classList.remove('active');
};

// ===== Logout =====
document.getElementById('logout-btn').addEventListener('click', async () => {
  await fetch(`${API}/auth/logout`, {
    method: 'POST',
    headers: {'Authorization': 'Bearer ' + TOKEN}
  });
  localStorage.clear();
  window.location.href = '/';
});

// ===== Init =====
(async function init() {
  try {
    // Show user name in nav
    const fullName = localStorage.getItem('fittrack_full_name') || 'User';
    document.getElementById('current-user-name').textContent = fullName;
    document.getElementById('welcome-name').textContent = fullName;

    // Load shared catalogs
    exercisesCache = await api('/exercises');
    categoriesCache = await api('/categories');
    musclesCache = await api('/muscles');

    // Fill filters
    document.getElementById('ex-filter-cat').innerHTML =
      '<option value="">All categories</option>' +
      categoriesCache.map(c => `<option value="${c.category_name}">${c.category_name}</option>`).join('');

    document.getElementById('e-category').innerHTML =
      categoriesCache.map(c => `<option value="${c.category_id}">${c.category_name}</option>`).join('');
    document.getElementById('e-muscle').innerHTML =
      musclesCache.map(m => `<option value="${m.muscle_id}">${m.muscle_name}</option>`).join('');

    // Load dashboard
    loadDashboard();
  } catch (err) {
    console.error('Init failed:', err);
  }
})();

// ===== Navigation =====
document.querySelectorAll('.nav-link').forEach(link => {
  link.addEventListener('click', () => {
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
    document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
    link.classList.add('active');
    const section = link.dataset.section;
    document.getElementById(section).classList.add('active');
    loadSection(section);
  });
});

function loadSection(name) {
  if (name === 'dashboard') loadDashboard();
  if (name === 'workouts')  loadWorkouts();
  if (name === 'exercises') loadExercises();
  if (name === 'progress')  loadProgress();
  if (name === 'goals')     loadGoals();
  if (name === 'memberships') loadMemberships();
}

// ===== Dashboard (each section in its own try/catch) =====
async function loadDashboard() {
  try {
    const d = await api('/dashboard');
    if (d && !d.error) {
      document.getElementById('welcome-name').textContent = d.full_name || 'athlete';
      document.getElementById('stat-workouts').textContent = d.total_workouts || 0;
      document.getElementById('stat-bmi').textContent = d.bmi || '—';
      document.getElementById('stat-goals').textContent = d.active_goals || 0;
      document.getElementById('stat-badges').textContent = d.badges || 0;
    }
  } catch (err) { console.error('Dashboard failed:', err); }

  try {
    const mems = await api('/memberships');
    const active = (mems || []).find(m => m.days_remaining > 0) || (mems && mems[0]);
    document.getElementById('stat-plan').textContent = active ? active.plan_name : 'None';
  } catch (err) {
    console.error('Memberships failed:', err);
    document.getElementById('stat-plan').textContent = 'None';
  }

  try {
    const weekly = await api('/analytics/weekly');
    drawBarChart('weekly-chart', (weekly || []).reverse(), 'minutes');
  } catch (err) {
    console.error('Weekly failed:', err);
    document.getElementById('weekly-chart').innerHTML = '<div class="empty-state">No data yet</div>';
  }

  try {
    const board = await api('/analytics/leaderboard');
    document.getElementById('leaderboard-list').innerHTML = (board || []).map((u, i) => `
      <div class="list-item">
        <div class="list-item-left">
          <h4>${i+1}. ${u.full_name}</h4>
          <p>${u.workouts} workouts · ${Math.round(u.total_cal||0)} cal</p>
        </div>
        <div class="list-item-right">${u.total_min}<span style="font-size:0.7rem">min</span></div>
      </div>
    `).join('') || '<div class="empty-state">No data yet</div>';
  } catch (err) {
    console.error('Leaderboard failed:', err);
    document.getElementById('leaderboard-list').innerHTML = '<div class="empty-state">No data</div>';
  }

  try {
    const top = await api('/analytics/top-exercises');
    document.getElementById('top-exercises').innerHTML = (top || []).map(t => `
      <div class="list-item">
        <div class="list-item-left"><h4>${t.exercise_name}</h4></div>
        <div class="list-item-right">${t.times_done}<span style="font-size:0.7rem">×</span></div>
      </div>
    `).join('') || '<div class="empty-state">No data yet</div>';
  } catch (err) {
    console.error('Top exercises failed:', err);
    document.getElementById('top-exercises').innerHTML = '<div class="empty-state">No data</div>';
  }
}

function drawBarChart(containerId, data, valueKey) {
  const c = document.getElementById(containerId);
  if (!data || !data.length) {
    c.innerHTML = '<div class="empty-state">No data yet — log a workout!</div>';
    return;
  }
  const max = Math.max(...data.map(d => d[valueKey] || 0), 1);
  c.innerHTML = '<div class="bar-chart">' + data.map(d => `
    <div class="bar" style="height:${((d[valueKey]||0)/max)*100}%">
      <div class="bar-value">${d[valueKey]||0}</div>
      
    </div>
  `).join('') + '</div>';
}

// ===== Workouts (with full exercise breakdown) =====
async function loadWorkouts() {
  try {
    const ws = await api('/workouts');
    const list = document.getElementById('workout-list');
    if (!ws.length) {
      list.innerHTML = '<div class="empty-state">No workouts yet. Log your first one!</div>';
      return;
    }

    list.innerHTML = ws.map(w => {
      // Build the exercise breakdown rows. Each row shows everything
      // the user entered when logging the workout: name, sets, reps,
      // weight (kg), and duration (min). We hide fields that are zero
      // to keep cardio-style entries clean.
      const exRows = (w.exercises || []).map(ex => {
        const parts = [];
        if (ex.sets > 0)         parts.push(`${ex.sets} sets`);
        if (ex.reps > 0)         parts.push(`${ex.reps} reps`);
        if (ex.weight_kg > 0)    parts.push(`${ex.weight_kg} kg`);
        if (ex.duration_min > 0) parts.push(`${ex.duration_min} min`);
        const detail = parts.length ? parts.join(' · ') : '—';
        return `
          <div class="we-row">
            <span class="we-name">${ex.exercise_name}</span>
            <span class="we-detail">${detail}</span>
          </div>`;
      }).join('') || '<div class="we-empty">No exercises recorded</div>';

      const loggedAt = w.created_at_uae
        ? `<span class="we-logged">Logged ${fmtDateTimeUAE(w.created_at_uae)}</span>`
        : '';

      return `
      <div class="workout-card">
        <div class="workout-card-header">
          <div class="workout-card-left">
            <h4>${fmtDateUAE(w.workout_date)}</h4>
            <p>${w.exercise_count} exercise${w.exercise_count===1?'':'s'} ·
               ${Math.round(w.total_calories||0)} cal ·
               ${w.notes || 'No notes'}</p>
            ${loggedAt}
          </div>
          <div class="workout-card-right">
            <div class="list-item-right">${w.duration_min}<span style="font-size:0.7rem">min</span></div>
            <button class="btn-danger" onclick="deleteWorkout(${w.workout_id})">DELETE</button>
          </div>
        </div>
        <div class="we-list">${exRows}</div>
      </div>`;
    }).join('');
  } catch (err) { console.error(err); }
}

async function deleteWorkout(id) {
  if (!confirm('Delete this workout?')) return;
  await fetch(`${API}/workouts/${id}`, {
    method: 'DELETE',
    headers: {'Authorization': 'Bearer ' + TOKEN}
  });
  toast('Workout deleted');
  loadWorkouts();
  loadDashboard();
}

function addExerciseRow() {
  const div = document.getElementById('w-exercises');
  const row = document.createElement('div');
  row.className = 'exercise-row';
  row.innerHTML = `
    <select class="ex-id">${exercisesCache.map(e => `<option value="${e.exercise_id}">${e.exercise_name}</option>`).join('')}</select>
    <input type="number" class="ex-sets" placeholder="Sets" min="0">
    <input type="number" class="ex-reps" placeholder="Reps" min="0">
    <input type="number" class="ex-weight" placeholder="Kg" min="0" step="0.5">
    <input type="number" class="ex-dur" placeholder="Min" min="0">
    <button type="button" class="btn-danger" onclick="this.parentElement.remove()">×</button>
  `;
  div.appendChild(row);
}

document.getElementById('workout-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const exercises = [...document.querySelectorAll('.exercise-row')].map(r => ({
    exercise_id: +r.querySelector('.ex-id').value,
    sets:        +r.querySelector('.ex-sets').value || 0,
    reps:        +r.querySelector('.ex-reps').value || 0,
    weight_kg:   +r.querySelector('.ex-weight').value || 0,
    duration_min:+r.querySelector('.ex-dur').value || 0
  }));
  const data = {
    workout_date: document.getElementById('w-date').value,
    duration_min: +document.getElementById('w-duration').value,
    notes: document.getElementById('w-notes').value,
    exercises
  };
  const res = await api('/workouts', { method: 'POST', body: JSON.stringify(data) });
  if (res.workout_id) {
    toast('Workout logged!');
    closeModal('workout-modal');
    e.target.reset();
    document.getElementById('w-exercises').innerHTML = '';
    loadWorkouts();
    loadDashboard();
  } else {
    toast(res.error || 'Failed', true);
  }
});

// ===== Exercises =====
function loadExercises() {
  renderExercises(exercisesCache);
  document.getElementById('ex-search').oninput = filterExercises;
  document.getElementById('ex-filter-cat').onchange = filterExercises;
}

function filterExercises() {
  const q = document.getElementById('ex-search').value.toLowerCase();
  const cat = document.getElementById('ex-filter-cat').value;
  const filtered = exercisesCache.filter(e =>
    e.exercise_name.toLowerCase().includes(q) &&
    (!cat || e.category_name === cat)
  );
  renderExercises(filtered);
}

function renderExercises(list) {
  const el = document.getElementById('exercise-list');
  if (!list.length) { el.innerHTML = '<div class="empty-state">No exercises found</div>'; return; }
  el.innerHTML = list.map(e => `
    <div class="exercise-card">
      <h3>${e.exercise_name}</h3>
      <div class="text-dim" style="font-size:0.85rem">${e.calories_per_min || 0} cal/min</div>
      <div class="meta">
        <span>${e.category_name}</span>
        <span>${e.muscle_name}</span>
        <span>${e.difficulty}</span>
      </div>
    </div>
  `).join('');
}

document.getElementById('exercise-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = {
    exercise_name: document.getElementById('e-name').value,
    category_id: +document.getElementById('e-category').value,
    muscle_id:   +document.getElementById('e-muscle').value,
    difficulty:  document.getElementById('e-diff').value,
    calories_per_min: +document.getElementById('e-cal').value || null,
    description: document.getElementById('e-desc').value
  };
  const res = await api('/exercises', { method: 'POST', body: JSON.stringify(data) });
  if (res.exercise_id) {
    toast('Exercise added!');
    closeModal('exercise-modal');
    e.target.reset();
    exercisesCache = await api('/exercises');
    renderExercises(exercisesCache);
  } else { toast(res.error || 'Failed', true); }
});

// ===== Progress =====
async function loadProgress() {
  try {
    const logs = await api('/progress');
    const chartC = document.getElementById('progress-chart');
    const list = document.getElementById('progress-list');

    if (!logs.length) {
      chartC.innerHTML = '<div class="empty-state">No progress logged yet</div>';
      list.innerHTML = '';
      return;
    }

    const w = 600, h = 200, pad = 40;
    const weights = logs.map(l => l.weight_kg);
    const minW = Math.min(...weights) - 1, maxW = Math.max(...weights) + 1;
    const points = logs.map((l, i) => {
      const x = pad + (i / Math.max(logs.length - 1, 1)) * (w - 2*pad);
      const y = h - pad - ((l.weight_kg - minW) / (maxW - minW)) * (h - 2*pad);
      return `${x},${y}`;
    }).join(' ');

    chartC.innerHTML = `
      <svg viewBox="0 0 ${w} ${h}" class="line-chart" preserveAspectRatio="none">
        <polyline fill="none" stroke="#d6ff3d" stroke-width="2.5" points="${points}"/>
        ${logs.map((l, i) => {
          const x = pad + (i / Math.max(logs.length - 1, 1)) * (w - 2*pad);
          const y = h - pad - ((l.weight_kg - minW) / (maxW - minW)) * (h - 2*pad);
          return `<circle cx="${x}" cy="${y}" r="4" fill="#d6ff3d"/>
                  <text x="${x}" y="${y-10}" fill="#f4f4f4" font-size="10" text-anchor="middle">${l.weight_kg}kg</text>`;
        }).join('')}
      </svg>`;

    list.innerHTML = logs.slice().reverse().map(l => `
      <div class="list-item">
        <div class="list-item-left">
          <h4>${fmtDateUAE(l.log_date)}</h4>
          <p>${l.notes || 'No notes'} ${l.body_fat_pct ? '· '+l.body_fat_pct+'% BF' : ''}</p>
        </div>
        <div class="list-item-right">${l.weight_kg}<span style="font-size:0.7rem">kg</span></div>
      </div>
    `).join('');
  } catch (err) { console.error(err); }
}

document.getElementById('progress-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = {
    log_date: document.getElementById('p-date').value,
    weight_kg: +document.getElementById('p-weight').value,
    body_fat_pct: +document.getElementById('p-fat').value || null,
    notes: document.getElementById('p-notes').value
  };
  const res = await api('/progress', { method: 'POST', body: JSON.stringify(data) });
  if (res.log_id) {
    toast('Weight logged!');
    closeModal('progress-modal');
    e.target.reset();
    loadProgress();
    loadDashboard();
  } else { toast(res.error || 'Failed', true); }
});

// ===== Goals =====
async function loadGoals() {
  try {
    const goals = await api('/goals');
    const list = document.getElementById('goal-list');
    if (!goals.length) { list.innerHTML = '<div class="empty-state">No goals yet. Set your first one!</div>'; return; }
    list.innerHTML = goals.map(g => {
      const pct = Math.min(100, Math.round(((g.current_value||0)/g.target_value)*100));
      const statusColor = g.status === 'Achieved' ? 'var(--accent)' :
                         g.status === 'Active' ? 'var(--accent-3)' : 'var(--text-dim)';
      return `
      <div class="goal-card">
        <h3>${g.goal_type}</h3>
        <p class="text-dim" style="font-size:0.85rem">Deadline: ${fmtDateUAE(g.deadline)}</p>
        <div style="display:flex;justify-content:space-between;margin-top:0.5rem">
          <span style="font-family:'Bebas Neue';font-size:1.5rem">${g.current_value||0} / ${g.target_value} ${g.unit}</span>
          <span style="color:${statusColor};font-size:0.8rem">${g.status}</span>
        </div>
        <div class="progress-bar"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
      </div>`;
    }).join('');
  } catch (err) { console.error(err); }
}

document.getElementById('goal-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = {
    goal_type: document.getElementById('g-type').value,
    target_value: +document.getElementById('g-target').value,
    unit: document.getElementById('g-unit').value,
    deadline: document.getElementById('g-deadline').value
  };
  const res = await api('/goals', { method: 'POST', body: JSON.stringify(data) });
  if (res.goal_id) {
    toast('Goal created!');
    closeModal('goal-modal');
    e.target.reset();
    loadGoals();
    loadDashboard();
  } else { toast(res.error || 'Failed', true); }
});

// ===== Memberships =====
async function loadMemberships() {
  try {
    const [plans, mems] = await Promise.all([
      api('/membership-plans'),
      api('/memberships')
    ]);

    const active = (mems || []).find(m => m.days_remaining > 0);
    const cur = document.getElementById('current-membership');
    if (active) {
      cur.innerHTML = `
        <div class="membership-info">
          <div><div class="label">PLAN</div><div class="value text-accent">${active.plan_name}</div></div>
          <div><div class="label">DAYS LEFT</div><div class="value">${active.days_remaining}</div></div>
          <div><div class="label">EXPIRES</div><div class="value" style="font-size:1.1rem">${fmtDateUAE(active.end_date)}</div></div>
          <div><div class="label">STATUS</div><div class="value">${active.payment_status}</div></div>
          <div><div class="label">AUTO-RENEW</div><div class="value">${active.auto_renew ? 'ON' : 'OFF'}</div></div>
          <div><div class="label">PRICE</div><div class="value">$${active.price_per_month}/mo</div></div>
          <div><div class="label">PAID ON (UAE)</div><div class="value" style="font-size:1rem">${fmtDateTimeUAE(active.paid_at_uae)}</div></div>
        </div>
      `;
    } else {
      cur.innerHTML = '<div class="empty-state">No active membership. Choose a plan below.</div>';
    }

    const currentPlanName = active ? active.plan_name : null;
    const grid = document.getElementById('plans-grid');
    grid.innerHTML = plans.map(p => {
      const isCurrent = p.plan_name === currentPlanName;
      const isFeatured = p.plan_name === 'Premium';
      const featureList = (p.features || '').split(',').map(f => `<li>${f.trim()}</li>`).join('');
      return `
        <div class="plan-card ${isCurrent ? 'current' : ''} ${isFeatured && !isCurrent ? 'featured' : ''}">
          ${isCurrent ? '<span class="plan-badge-current">CURRENT</span>' : ''}
          ${isFeatured && !isCurrent ? '<span class="plan-badge-popular">POPULAR</span>' : ''}
          <div class="plan-name">${p.plan_name}</div>
          <div class="plan-price">$${p.price_per_month}<small>/mo</small></div>
          <div class="text-dim" style="font-size:0.8rem">${p.duration_months} month${p.duration_months>1?'s':''} · max goals: ${p.max_goals === 99 ? '∞' : p.max_goals}</div>
          <ul class="plan-features">${featureList}</ul>
          ${isCurrent
            ? '<button class="btn-secondary" disabled style="opacity:0.5">Active</button>'
            : `<button class="btn-primary" onclick="subscribe(${p.plan_id})">SUBSCRIBE</button>`}
        </div>
      `;
    }).join('');

    const hist = document.getElementById('membership-history');
    hist.innerHTML = mems.length ? mems.map(m => `
      <div class="list-item">
        <div class="list-item-left">
          <h4>${m.plan_name}</h4>
          <p>${fmtDateUAE(m.start_date)} → ${fmtDateUAE(m.end_date)} · ${m.payment_status} · $${m.amount_paid}</p>
          <p class="text-dim" style="font-size:0.8rem">Paid on ${fmtDateTimeUAE(m.paid_at_uae)}</p>
        </div>
        <div class="list-item-right" style="font-size:1rem">
          ${m.days_remaining > 0 ? `${m.days_remaining}d left` : 'Expired'}
        </div>
      </div>
    `).join('') : '<div class="empty-state">No history yet</div>';
  } catch (err) { console.error(err); }
}

async function subscribe(planId) {
  if (!confirm('Subscribe to this plan?')) return;
  const res = await api('/memberships', {
    method: 'POST',
    body: JSON.stringify({ plan_id: planId })
  });
  if (res.membership_id) {
    toast('Subscribed!');
    loadMemberships();
    loadDashboard();
  } else {
    toast(res.error || 'Failed', true);
  }
}
