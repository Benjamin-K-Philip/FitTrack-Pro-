import mysql.connector
import bcrypt


DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': '123456',    
    'database': 'fittrack'
}


# The new password to set for all seed users
NEW_PASSWORD = 'password123'


# ============================================================
# CONNECT TO MYSQL
# ============================================================
print('=' * 55)
print(' Setting Real Passwords for Seed Users')
print('=' * 55)
print('[*] Connecting to MySQL...')

try:
    conn = mysql.connector.connect(**DB_CONFIG)
    cur = conn.cursor()
    print('[OK] Connected')
except mysql.connector.Error as e:
    print(f'[ERROR] Could not connect: {e}')
    print('  Check that MySQL is running and password in DB_CONFIG is correct')
    exit(1)

# ============================================================
# GENERATING A REAL BCRYPT HASH
# ============================================================
print(f'\n[*] Hashing password "{NEW_PASSWORD}" with bcrypt (cost=10)...')
new_hash = bcrypt.hashpw(NEW_PASSWORD.encode('utf-8'), bcrypt.gensalt(rounds=10)).decode('utf-8')
print(f'[OK] Generated hash: {new_hash[:30]}...')


# ============================================================
# UPDATING ALL SEED USERS
# ============================================================
print(f'\n[*] Updating seed users with the new hash...')
cur.execute(
    "UPDATE users SET password_hash = %s WHERE email LIKE %s",
    (new_hash, '%@fittrack.com')
)
conn.commit()
rows_updated = cur.rowcount
print(f'[OK] Updated {rows_updated} users')


# ============================================================
# DISPLAYING UPDATED USERS
# ============================================================
print('\n[*] Updated users:')
cur.execute("""
    SELECT user_id, username, email, LEFT(password_hash, 30) AS hash_start
    FROM users
    WHERE email LIKE '%@fittrack.com'
    ORDER BY user_id
""")
for user_id, username, email, hash_start in cur.fetchall():
    print(f'    {user_id}  {username:<10}  {email:<25}  {hash_start}...')

cur.close()
conn.close()


# ============================================================
# DONE
# ============================================================
print('\n' + '=' * 55)
print(' [OK] Password update complete')
print('=' * 55)
print(f'\n You can now log in to the authentication version with:')
print(f'   alex@fittrack.com  /  {NEW_PASSWORD}')
print(f'   sara@fittrack.com  /  {NEW_PASSWORD}')
print(f'   mike@fittrack.com  /  {NEW_PASSWORD}')
print(f'   priya@fittrack.com /  {NEW_PASSWORD}')
 
