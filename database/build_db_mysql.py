import mysql.connector
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# MySQL CONNECTION CONFIG -- EDIT IF YOUR PASSWORD DIFFERS
# ============================================================
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': '123456',     # <-- CHANGE THIS to your MySQL password
}

DB_NAME = 'fittrack'

# ============================================================
# CONNECT TO MYSQL
# ============================================================
print('=' * 55)
print(' FitTrack Pro - MySQL Database Builder')
print('=' * 55)
print('[*] Connecting to MySQL Server...')
try:
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()
    print('[OK] Connected to MySQL')
except mysql.connector.Error as e:
    print(f'[ERROR] Could not connect: {e}')
    print('  Check that:')
    print('  1. MySQL Server is running (services.msc -> MySQL80)')
    print('  2. Password in DB_CONFIG is correct')
    exit(1)

# ============================================================
# CHECKING IF DATABASE EXISTS 
# ============================================================
cursor.execute('SHOW DATABASES')
existing = [row[0] for row in cursor.fetchall()]

if DB_NAME in existing:
    print(f'\n[!] Database "{DB_NAME}" already exists.')
    print(f'    Continuing will DELETE all tables and data inside it.')
    answer = input('    Type "yes" to rebuild, anything else to cancel: ').strip().lower()
    if answer != 'yes':
        print('    Cancelled. Database left unchanged.')
        cursor.close()
        conn.close()
        exit(0)


# ============================================================
# CREATING FRESH DATABASE 
# ============================================================
print(f'\n[*] Creating database "{DB_NAME}"...')
cursor.execute(f'DROP DATABASE IF EXISTS {DB_NAME}')
cursor.execute(f'CREATE DATABASE {DB_NAME}')
cursor.execute(f'USE {DB_NAME}')
print(f'[OK] Database "{DB_NAME}" created and selected')


# ============================================================
#Parsing SQL with DELIMITER directives properly
# ============================================================
def parse_statements(sql_script):
    """Split SQL into statements, handling DELIMITER for triggers."""
    statements = []
    current_delimiter = ';'
    buffer = []

    for line in sql_script.splitlines():
        stripped = line.strip()

        # Skip empty lines and comments
        if not stripped or stripped.startswith('--'):
            continue

        # Skip CREATE DATABASE and USE - Python handles these
        upper_stripped = stripped.upper()
        if upper_stripped.startswith('CREATE DATABASE') or \
           upper_stripped.startswith('USE '):
            continue

        # Handle DELIMITER directive
        if upper_stripped.startswith('DELIMITER'):
            if buffer:
                stmt = '\n'.join(buffer).strip()
                if stmt:
                    statements.append(stmt)
                buffer = []
            parts = stripped.split()
            if len(parts) > 1:
                current_delimiter = parts[1]
            continue

        buffer.append(line)

        # Statement ends when line ends with current delimiter
        if stripped.endswith(current_delimiter):
            joined = '\n'.join(buffer).strip()
            if joined.endswith(current_delimiter):
                joined = joined[:-len(current_delimiter)].strip()
            if joined:
                statements.append(joined)
            buffer = []

    if buffer:
        stmt = '\n'.join(buffer).strip()
        if stmt:
            statements.append(stmt)

    return statements


def run_sql_file(filepath):
    """Execute all statements in a SQL file."""
    filename = os.path.basename(filepath)
    print(f'\n[*] Running {filename}...')

    if not os.path.exists(filepath):
        print(f'    [SKIP] File not found: {filepath}')
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        sql_script = f.read()

    statements = parse_statements(sql_script)
    success = 0
    failed = 0

    for stmt in statements:
        if not stmt.strip():
            continue
        try:
            cursor.execute(stmt)
            try:
                cursor.fetchall()
            except mysql.connector.errors.InterfaceError:
                pass
            success += 1
        except mysql.connector.Error as e:
            failed += 1
            if failed == 1:
                print(f'    [WARN] First failure: {e}')
                preview = stmt.replace('\n', ' ')[:80]
                print(f'    Statement: {preview}...')

    status = 'OK' if failed == 0 else 'PARTIAL'
    print(f'    [{status}] {success} succeeded, {failed} failed')


# ============================================================
# RUNNNING SQL FILE 
# ============================================================
run_sql_file(os.path.join(HERE, 'fittrack_complete_mysql.sql'))


# ============================================================
# DATABASE SUMMARY
# ============================================================
print('\n' + '=' * 55)
print(' Database Summary')
print('=' * 55)

tables = ['users', 'membership_plans', 'memberships', 'exercises',
          'workouts', 'workout_exercises', 'progress_log', 'goals',
          'foods', 'meal_logs', 'achievements', 'notifications',
          'exercise_categories', 'muscle_groups']

total_rows = 0
for table in tables:
    try:
        cursor.execute(f'SELECT COUNT(*) FROM {table}')
        count = cursor.fetchone()[0]
        total_rows += count
        print(f'    {table:<22} {count:>4} rows')
    except mysql.connector.Error:
        print(f'    {table:<22}   (missing)')

# Show triggers
print('\n[*] Triggers created:')
cursor.execute("""
    SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE
    FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = %s
""", (DB_NAME,))
triggers = cursor.fetchall()
for trigger_name, table_name in triggers:
    print(f'    {trigger_name:<35} on {table_name}')

# Show views
print('\n[*] Views created:')
cursor.execute("""
    SELECT TABLE_NAME
    FROM information_schema.VIEWS
    WHERE TABLE_SCHEMA = %s
""", (DB_NAME,))
views = cursor.fetchall()
for (view_name,) in views:
    print(f'    {view_name}')

conn.commit()
cursor.close()
conn.close()

print('\n' + '=' * 55)
print(f' [OK] MySQL database "{DB_NAME}" built successfully')
print(f' Total rows seeded: {total_rows}')
print(f' Triggers: {len(triggers)}    Views: {len(views)}')
print('=' * 55)
print('\n NEXT STEPS:')
print('   1. Open MySQL Workbench to verify the database visually')
print('   2. Run: cd ..\\backend && python app.py')
print('   3. Open: http://fittrack.io   (or http://fittrack.io:5000)')
