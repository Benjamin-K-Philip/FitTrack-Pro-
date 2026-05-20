from flask import Flask, request, jsonify, send_from_directory, g
import mysql.connector
from mysql.connector import Error
import bcrypt
import os
import secrets
from datetime import datetime, date, timedelta, timezone
from functools import wraps

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.join(BASE_DIR, '..', 'frontend')

# ============================================================
# MySQL CONNECTION  
# ============================================================
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': '123456',
    'database': 'fittrack',
    'autocommit': False
}

# ============================================================
# UAE TIMEZONE (Asia/Dubai is UTC+4)
# ============================================================
UAE_TZ = timezone(timedelta(hours=4))

def to_uae(dt):
    # Converting datetime to a UAE format datetime.

    if dt is None:
        return None
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=UAE_TZ)
        else:
            dt = dt.astimezone(UAE_TZ)
        return dt.isoformat()
    if isinstance(dt, date):
        return dt.isoformat()
    return str(dt)


app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path='')

# Simple in-memory token store: {token: user_id}
# In production this would be Redis or a database table.
ACTIVE_TOKENS = {}

# ============================================================
# Database helpers
# ============================================================
def get_db():
    if 'db' not in g:
        g.db = mysql.connector.connect(**DB_CONFIG)
    return g.db

@app.teardown_appcontext
def close_db(exc):
    db = g.pop('db', None)
    if db is not None and db.is_connected():
        db.close()

def query_db(query, args=(), one=False):
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute(query, args)
    rows = cur.fetchall()
    cur.close()
    return (rows[0] if rows else None) if one else rows

def execute_db(query, args=()):
    db = get_db()
    cur = db.cursor()
    cur.execute(query, args)
    db.commit()
    last_id = cur.lastrowid
    cur.close()
    return last_id


# ============================================================
# Authentication helpers
# ============================================================
def hash_password(plain):
    return bcrypt.hashpw(plain.encode('utf-8'), bcrypt.gensalt(rounds=10)).decode('utf-8')

def check_password(plain, hashed):
    try:
        return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))
    except Exception:
        return False

def get_token_from_request():
    """Extract token from Authorization header."""
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return auth[7:]
    return None

def current_user_id():
    """Return the user_id of the requester, or None."""
    token = get_token_from_request()
    if not token:
        return None
    return ACTIVE_TOKENS.get(token)

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        uid = current_user_id()
        if uid is None:
            return jsonify({'error': 'Authentication required', 'code': 'NOT_LOGGED_IN'}), 401
        return f(*args, **kwargs)
    return decorated


# ============================================================
# Frontend Routes
# ============================================================
@app.route('/')
def root():
    """Show login page by default."""
    return send_from_directory(FRONTEND_DIR, 'login.html')

@app.route('/app')
def app_page():
    """Show main app (after login)."""
    return send_from_directory(FRONTEND_DIR, 'app.html')


# ============================================================
# AUTHENTICATION ROUTES
# ============================================================
@app.route('/api/auth/signup', methods=['POST'])
def signup():
    d = request.get_json() or {}

    # Validate required fields
    for field in ['username', 'email', 'password', 'full_name']:
        if not d.get(field):
            return jsonify({'error': f'Missing field: {field}'}), 400

    if len(d['password']) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400

    pw_hash = hash_password(d['password'])

    try:
        # Stamp created_at with current UAE time so new signups also have UAE-correct timestamps
        now_uae = datetime.now(UAE_TZ).strftime('%Y-%m-%d %H:%M:%S')
        uid = execute_db('''INSERT INTO users
            (username, email, password_hash, full_name, age, gender, height_cm, weight_kg, fitness_level, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)''',
            (d['username'], d['email'], pw_hash, d['full_name'],
             d.get('age'), d.get('gender'), d.get('height_cm'),
             d.get('weight_kg'), d.get('fitness_level', 'Beginner'), now_uae))

        # Generate token and return it
        token = secrets.token_urlsafe(32)
        ACTIVE_TOKENS[token] = uid

        return jsonify({
            'token': token,
            'user_id': uid,
            'username': d['username'],
            'full_name': d['full_name']
        }), 201
    except Error as e:
        msg = str(e)
        if 'Duplicate' in msg and 'username' in msg:
            return jsonify({'error': 'Username already taken'}), 400
        if 'Duplicate' in msg and 'email' in msg:
            return jsonify({'error': 'Email already registered'}), 400
        return jsonify({'error': msg}), 400


@app.route('/api/auth/login', methods=['POST'])
def login():
    d = request.get_json() or {}
    email = (d.get('email') or '').strip()
    password = d.get('password') or ''

    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400

    user = query_db(
        'SELECT user_id, username, full_name, password_hash FROM users WHERE email = %s',
        (email,), one=True
    )

    if not user or not check_password(password, user['password_hash']):
        return jsonify({'error': 'Invalid email or password'}), 401

    token = secrets.token_urlsafe(32)
    ACTIVE_TOKENS[token] = user['user_id']

    return jsonify({
        'token': token,
        'user_id': user['user_id'],
        'username': user['username'],
        'full_name': user['full_name']
    })


@app.route('/api/auth/logout', methods=['POST'])
def logout():
    token = get_token_from_request()
    if token and token in ACTIVE_TOKENS:
        del ACTIVE_TOKENS[token]
    return jsonify({'message': 'Logged out'})


@app.route('/api/auth/me', methods=['GET'])
@login_required
def whoami():
    uid = current_user_id()
    user = query_db(
        'SELECT user_id, username, email, full_name FROM users WHERE user_id = %s',
        (uid,), one=True
    )
    return jsonify(user) if user else (jsonify({'error': 'not found'}), 404)


# ============================================================
# DASHBOARD
# ============================================================
@app.route('/api/dashboard', methods=['GET'])
@login_required
def get_dashboard():
    uid = current_user_id()
    user = query_db('SELECT * FROM v_user_dashboard WHERE user_id = %s', (uid,), one=True)
    return jsonify(user) if user else (jsonify({'error': 'not found'}), 404)


# ============================================================
# EXERCISES (read-only catalog, shared)
# ============================================================
@app.route('/api/exercises', methods=['GET'])
@login_required
def get_exercises():
    rows = query_db('''
        SELECT e.exercise_id, e.exercise_name, e.difficulty, e.calories_per_min,
               ec.category_name, mg.muscle_name
        FROM exercises e
        JOIN exercise_categories ec ON e.category_id = ec.category_id
        JOIN muscle_groups mg ON e.muscle_id = mg.muscle_id
        ORDER BY e.exercise_name
    ''')
    return jsonify(rows)

@app.route('/api/categories', methods=['GET'])
@login_required
def get_categories():
    return jsonify(query_db('SELECT * FROM exercise_categories'))

@app.route('/api/muscles', methods=['GET'])
@login_required
def get_muscles():
    return jsonify(query_db('SELECT * FROM muscle_groups'))

@app.route('/api/exercises', methods=['POST'])
@login_required
def create_exercise():
    d = request.get_json()
    try:
        eid = execute_db('''INSERT INTO exercises
            (exercise_name, category_id, muscle_id, difficulty, calories_per_min, description)
            VALUES (%s, %s, %s, %s, %s, %s)''',
            (d['exercise_name'], d['category_id'], d['muscle_id'],
             d.get('difficulty', 'Medium'), d.get('calories_per_min'), d.get('description')))
        return jsonify({'exercise_id': eid}), 201
    except Error as e:
        return jsonify({'error': str(e)}), 400


# ============================================================
# WORKOUTS (and their exercises) OF USER 
# ============================================================
@app.route('/api/workouts', methods=['GET'])
@login_required
def get_workouts():
    """Return each workout with its exercises (name, sets, reps, weight, minutes)
       and a UAE-formatted created-at timestamp."""
    uid = current_user_id()
    workouts = query_db('''
        SELECT w.workout_id, w.workout_date, w.duration_min,
               w.notes, w.total_calories, w.created_at
        FROM workouts w
        WHERE w.user_id = %s
        ORDER BY w.workout_date DESC, w.created_at DESC
    ''', (uid,))

    if not workouts:
        return jsonify([])

    # Pull every exercise row for those workouts in a single query
    workout_ids = [w['workout_id'] for w in workouts]
    placeholders = ','.join(['%s'] * len(workout_ids))
    ex_rows = query_db(f'''
        SELECT we.workout_id, we.we_id,
               e.exercise_id, e.exercise_name,
               we.sets, we.reps, we.weight_kg, we.duration_min
        FROM workout_exercises we
        JOIN exercises e ON we.exercise_id = e.exercise_id
        WHERE we.workout_id IN ({placeholders})
        ORDER BY we.we_id
    ''', tuple(workout_ids))

    # Group exercises by workout_id
    by_wid = {}
    for r in ex_rows:
        by_wid.setdefault(r['workout_id'], []).append({
            'we_id':        r['we_id'],
            'exercise_id':  r['exercise_id'],
            'exercise_name': r['exercise_name'],
            'sets':         r['sets'],
            'reps':         r['reps'],
            'weight_kg':    float(r['weight_kg']) if r['weight_kg'] is not None else 0,
            'duration_min': r['duration_min']
        })

    # Build response with UAE-formatted timestamps and exercises array
    out = []
    for w in workouts:
        out.append({
            'workout_id':     w['workout_id'],
            'workout_date':   w['workout_date'].isoformat() if w['workout_date'] else None,
            'duration_min':   w['duration_min'],
            'notes':          w['notes'],
            'total_calories': float(w['total_calories']) if w['total_calories'] is not None else 0,
            'created_at_uae': to_uae(w['created_at']),
            'exercise_count': len(by_wid.get(w['workout_id'], [])),
            'exercises':      by_wid.get(w['workout_id'], [])
        })
    return jsonify(out)

@app.route('/api/workouts', methods=['POST'])
@login_required
def create_workout():
    uid = current_user_id()
    d = request.get_json()
    # Stamp created_at with current UAE wall-clock so the timeline is consistent
    now_uae = datetime.now(UAE_TZ).strftime('%Y-%m-%d %H:%M:%S')
    wid = execute_db('''INSERT INTO workouts
        (user_id, workout_date, duration_min, notes, created_at) VALUES (%s, %s, %s, %s, %s)''',
        (uid, d['workout_date'], d['duration_min'], d.get('notes', ''), now_uae))

    for ex in d.get('exercises', []):
        execute_db('''INSERT INTO workout_exercises
            (workout_id, exercise_id, sets, reps, weight_kg, duration_min)
            VALUES (%s, %s, %s, %s, %s, %s)''',
            (wid, ex['exercise_id'], ex.get('sets', 0), ex.get('reps', 0),
             ex.get('weight_kg', 0), ex.get('duration_min', 0)))
    return jsonify({'workout_id': wid, 'message': 'Workout logged!'}), 201

@app.route('/api/workouts/<int:wid>', methods=['DELETE'])
@login_required
def delete_workout(wid):
    uid = current_user_id()
    workout = query_db('SELECT user_id FROM workouts WHERE workout_id = %s', (wid,), one=True)
    if not workout:
        return jsonify({'error': 'Workout not found'}), 404
    if workout['user_id'] != uid:
        return jsonify({'error': 'Not authorized'}), 403
    execute_db('DELETE FROM workouts WHERE workout_id = %s', (wid,))
    return jsonify({'message': 'Deleted'})


# ============================================================
# PROGRESS OF USER 
# ============================================================
@app.route('/api/progress', methods=['GET'])
@login_required
def get_progress():
    uid = current_user_id()
    rows = query_db('SELECT * FROM progress_log WHERE user_id = %s ORDER BY log_date', (uid,))
    return jsonify(rows)

@app.route('/api/progress', methods=['POST'])
@login_required
def add_progress():
    uid = current_user_id()
    d = request.get_json()
    try:
        pid = execute_db('''INSERT INTO progress_log
            (user_id, log_date, weight_kg, body_fat_pct, notes) VALUES (%s, %s, %s, %s, %s)''',
            (uid, d['log_date'], d['weight_kg'],
             d.get('body_fat_pct'), d.get('notes')))
        return jsonify({'log_id': pid}), 201
    except Error as e:
        return jsonify({'error': str(e)}), 400


# ============================================================
# GOALS OF USER
# ============================================================
@app.route('/api/goals', methods=['GET'])
@login_required
def get_goals():
    uid = current_user_id()
    rows = query_db('SELECT * FROM goals WHERE user_id = %s ORDER BY deadline', (uid,))
    return jsonify(rows)

@app.route('/api/goals', methods=['POST'])
@login_required
def create_goal():
    uid = current_user_id()
    d = request.get_json()
    gid = execute_db('''INSERT INTO goals
        (user_id, goal_type, target_value, current_value, unit, deadline, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s)''',
        (uid, d['goal_type'], d['target_value'],
         d.get('current_value', 0), d['unit'], d['deadline'], d.get('status', 'Active')))
    return jsonify({'goal_id': gid}), 201


# ============================================================
# ACHIEVEMENTS OF USER 
# ============================================================
@app.route('/api/achievements')
@login_required
def get_achievements():
    uid = current_user_id()
    rows = query_db('SELECT * FROM achievements WHERE user_id = %s ORDER BY earned_date DESC', (uid,))
    return jsonify(rows)


# ============================================================
# MEMBERSHIPS OF USER — UAE-formatted purchase time
# ============================================================
@app.route('/api/membership-plans', methods=['GET'])
@login_required
def get_membership_plans():
    return jsonify(query_db('SELECT * FROM membership_plans ORDER BY price_per_month'))

@app.route('/api/memberships', methods=['GET'])
@login_required
def get_memberships():
    uid = current_user_id()
    rows = query_db('''
        SELECT m.membership_id, m.start_date, m.end_date,
               m.payment_status, m.auto_renew, m.amount_paid,
               m.created_at,
               mp.plan_name, mp.price_per_month, mp.features,
               mp.has_nutrition, mp.has_coach_access, mp.max_goals,
               DATEDIFF(m.end_date, CURDATE()) AS days_remaining
          FROM memberships m
          JOIN membership_plans mp ON m.plan_id = mp.plan_id
         WHERE m.user_id = %s
         ORDER BY m.end_date DESC
    ''', (uid,))

    # Format the purchase timestamp (created_at) and dates for the frontend
    out = []
    for m in rows:
        m_out = dict(m)
        m_out['paid_at_uae'] = to_uae(m['created_at'])
        if isinstance(m_out.get('start_date'), date):
            m_out['start_date'] = m_out['start_date'].isoformat()
        if isinstance(m_out.get('end_date'), date):
            m_out['end_date'] = m_out['end_date'].isoformat()
        # Drop the raw created_at to avoid double-serialization issues
        m_out.pop('created_at', None)
        # Decimal -> float for JSON
        if m_out.get('price_per_month') is not None:
            m_out['price_per_month'] = float(m_out['price_per_month'])
        if m_out.get('amount_paid') is not None:
            m_out['amount_paid'] = float(m_out['amount_paid'])
        out.append(m_out)
    return jsonify(out)

@app.route('/api/memberships', methods=['POST'])
@login_required
def create_membership():
    uid = current_user_id()
    d = request.get_json()
    plan = query_db('SELECT * FROM membership_plans WHERE plan_id = %s',
                    (d['plan_id'],), one=True)
    if not plan:
        return jsonify({'error': 'Invalid plan'}), 400

    start = date.fromisoformat(d.get('start_date', date.today().isoformat()))
    end = start + timedelta(days=30 * plan['duration_months'])
    amount = float(plan['price_per_month']) * plan['duration_months']

    try:
        # Stamp purchase time in UAE
        now_uae = datetime.now(UAE_TZ).strftime('%Y-%m-%d %H:%M:%S')
        mid = execute_db('''INSERT INTO memberships
            (user_id, plan_id, start_date, end_date, payment_status, auto_renew, amount_paid, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)''',
            (uid, d['plan_id'], start.isoformat(), end.isoformat(),
             d.get('payment_status', 'Paid'), d.get('auto_renew', 1), amount, now_uae))
        return jsonify({'membership_id': mid}), 201
    except Error as e:
        return jsonify({'error': str(e)}), 400


# ============================================================
# ANALYTICS
# ============================================================
@app.route('/api/analytics/weekly')
@login_required
def weekly_summary():
    uid = current_user_id()
    rows = query_db('''
        SELECT  DATE_FORMAT(workout_date, '%%Y-%%u') AS week,
                COUNT(*)              AS workouts,
                SUM(duration_min)     AS minutes,
                SUM(total_calories)   AS calories
        FROM    workouts
        WHERE   user_id = %s
        GROUP BY week ORDER BY week DESC LIMIT 8
    ''', (uid,))
    return jsonify(rows)

@app.route('/api/analytics/top-exercises')
@login_required
def top_exercises():
    rows = query_db('''
        SELECT e.exercise_name, COUNT(*) AS times_done
        FROM exercises e
        WHERE e.exercise_id IN (SELECT exercise_id FROM workout_exercises)
        GROUP BY e.exercise_id, e.exercise_name
        ORDER BY times_done DESC LIMIT 5
    ''')
    return jsonify(rows)

@app.route('/api/analytics/leaderboard')
@login_required
def leaderboard():
    rows = query_db('''
        SELECT u.full_name,
               (SELECT COUNT(*) FROM workouts w WHERE w.user_id = u.user_id) AS workouts,
               (SELECT COALESCE(SUM(duration_min),0) FROM workouts w WHERE w.user_id = u.user_id) AS total_min,
               (SELECT COALESCE(SUM(total_calories),0) FROM workouts w WHERE w.user_id = u.user_id) AS total_cal
        FROM users u ORDER BY total_min DESC LIMIT 10
    ''')
    return jsonify(rows)


# ============================================================
# HEALTH CHECK
# ============================================================
@app.route('/api/health')
def health():
    return jsonify({
        'status': 'ok',
        'time_uae': datetime.now(UAE_TZ).isoformat()
    })


if __name__ == '__main__':
    print('=' * 55)
    print(' FitTrack- Server is starting up with the following configuration:')
    print('=' * 55)
    print(f' Database: MySQL on {DB_CONFIG["host"]}:{DB_CONFIG["port"]}')
    print(f' Schema:   {DB_CONFIG["database"]}')
    print(' Authentication:     Token-based (Authorization header)')
    print(' Timezone: Asia/Dubai (UTC+4)')
    print(' URL:      http://fittrack.io') #(or http://fittrack.io:5000)
    print('=' * 55)
    # print(' Reminder: add this line to your hosts file once:')
    # print('   127.0.0.1   fittrack.io')
    # print('   (Windows: C:\\Windows\\System32\\drivers\\etc\\hosts)')
    # print('   (macOS / Linux: /etc/hosts)')
    # print('=' * 55)

    try:
        test = mysql.connector.connect(**DB_CONFIG)
        test.close()
        print(' [OK] MySQL connection successful')
    except Error as e:
        print(f' [ERROR] Could not connect to MySQL: {e}')
        exit(1)

    # ============================================================
    # Port 80 lets you visit http://fittrack.io with no port suffix.
    # On Windows it usually requires running this script as Administrator
    # (or stopping IIS / "World Wide Web Publishing Service"). If port 80
    # cannot be bound, we fall back to 5000 automatically — in that case
    # visit http://fittrack.io:5000
    # ============================================================
    try:
        app.run(host='0.0.0.0', port=80, debug=True)
    except (PermissionError, OSError) as e:
        print(f'\n [WARN] Could not bind port 80 ({e}).')
        print(' [INFO] Falling back to port 5000.')
        print(' [INFO] Open: http://fittrack.io:5000')
        app.run(host='0.0.0.0', port=5000, debug=True)
