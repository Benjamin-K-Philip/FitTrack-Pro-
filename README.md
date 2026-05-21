# FitTrack Pro

## Description
A full-stack health and fitness tracker powered by a 14-table MySQL database, a Python Flask backend, and an HTML/CSS/JavaScript frontend. Demonstrates normalized schema design, foreign keys, indexes, triggers, stored functions, procedures, views, and advanced SQL queries. Users can log workouts, track progress, set goals, earn achievements, and manage memberships.

---

## How the Code Works <br>
The FitTrack Pro system is built on a three-layer architecture: a MySQL database (data layer), a Flask Python backend (logic and API layer), and an HTML/JS frontend (presentation layer). The database is the heart of the project — every action a user takes on the website ultimately translates into SQL operations against the fittrack database.

➤ **MySQL Database (fittrack_database_mysql_func_and_proc.sql)**
This single SQL file builds the entire database and contains every structural element of the project. It is organized into clearly labelled sections:

 - **Database Creation:** Begins with CREATE DATABASE IF NOT EXISTS fittrack and USE fittrack to ensure a clean working environment. Each table is dropped (with DROP TABLE IF EXISTS) in reverse dependency order before being created, so the script can be re-run safely.
  
**14 Tables (Normalized Schema):** <br>
The schema is fully normalized with proper primary keys, foreign keys, CHECK constraints, UNIQUE constraints, and ON DELETE CASCADE rules. The tables are:
   - **users:—** stores account info, demographics (age, gender, height, weight), and a bcrypt password_hash.
**membership_plans and memberships:—** model the subscription system (Free, Premium, Pro, Annual variants).
**exercise_categories, muscle_groups, and exercises:—** a normalized exercise library where each exercise belongs to one category and targets one muscle group.
**workouts and workout_exercises:—** the latter is a junction table that resolves the many-to-many relationship between workouts and exercises (one workout has many exercises, and one exercise can appear in many workouts), with extra columns for sets, reps, weight, and duration.
**progress_log:—** tracks weight, body fat percentage, and muscle mass over time, with a UNIQUE (user_id, log_date) constraint to prevent duplicate entries on the same day.
**goals:—** fitness goals with type, target value, deadline, and status.
**foods and meal_logs:—** basic nutrition tracking module.
**achievements:—** badges (Bronze/Silver/Gold/Platinum) awarded to users.
**notifications:—** system messages for goals, workouts, achievements, and announcements.


Indexes: Five composite indexes are created on the most frequently queried columns (user_id + date combinations on workouts, progress_log, goals, meal_logs, and memberships) to speed up the dashboard and history queries.
5 Triggers: Automate side-effects so that the database stays consistent without the application layer having to remember every rule. The DELIMITER // directive is used so multi-statement trigger bodies can be parsed correctly:

trg_check_weight_goal — After a new progress_log row is inserted, automatically marks any active Weight Loss goal as 'Achieved' if the new weight has hit the target.
trg_workout_milestone — After a workout is inserted, checks whether the user has reached exactly 10 workouts. If so, it inserts a Bronze badge into achievements and a congratulatory message into notifications.
trg_update_workout_calories — After an exercise is added to a workout, automatically recalculates and updates the workout's total_calories based on each exercise's calories_per_min and duration_min.
trg_sync_user_weight — Keeps the users.weight_kg profile field synced with the latest progress_log entry.
trg_membership_welcome — When a paid membership is created, inserts a personalized welcome notification that includes the plan name and end date.


2 Views: Pre-computed virtual tables that simplify dashboard queries:

v_user_dashboard — aggregates each user's BMI, total workouts, active goals, and badge count into one row.
v_workout_details — joins workouts with their user and counts the exercises per workout.


Stored Function — fn_calculate_bmi: Takes weight (kg) and height (cm) as arguments and returns the BMI rounded to two decimal places using the standard formula weight / (height_m)².
Stored Procedure — sp_user_workout_summary: Accepts a user_id and returns the user's total workouts, total minutes, and total calories burned.
Seed Data: Pre-populates every table with sample records — 4 users (Alex, Sara, Mike, Priya), 18 exercises, 5 membership plans, sample workouts, progress logs, goals, foods, meal logs, achievements, and notifications — so the application is immediately demoable.
15 Sample Queries: The end of the file contains organized query examples covering basic SELECTs, multi-table JOINs (including a 5-table join), nested subqueries, correlated subqueries, aggregate functions with GROUP BY, and set operations (UNION).

➤ **Python Backend (build_db_mysql.py, set_passwords.py, app.py)**
The Python files act as the bridge between the SQL file and the live application. They all use the mysql-connector-python library to talk to MySQL.

build_db_mysql.py — The Database Builder: This is the script you run once to set up the database. It:

Connects to the local MySQL server using credentials in DB_CONFIG.
Checks if the fittrack database already exists and asks for confirmation before rebuilding.
Reads fittrack_database_mysql_func_and_proc.sql from disk and feeds it to a custom parse_statements() function, which intelligently splits the file into individual statements while respecting DELIMITER // directives needed for the triggers, function, and procedure.
Executes each statement through the MySQL connector cursor.
Prints a summary showing the row count of every table, plus the names of all triggers and views that were created.


set_passwords.py — Real Password Setup: The seed users in the SQL file have placeholder password hashes. This helper script connects to the fittrack database, generates a real bcrypt hash for the password password123, and updates every seed user's password_hash column with it — so the four demo accounts (alex, sara, mike, priya) can actually log in.
app.py — The Flask API Server: Exposes a RESTful API that the frontend calls. It uses mysql.connector to open a database connection per request (via Flask's g object), runs parameterized SQL queries against the fittrack database, and returns JSON. Routes include /api/auth/login, /api/auth/signup, /api/workouts, /api/exercises, /api/goals, /api/progress, /api/memberships, and dashboard endpoints. Passwords are hashed and verified with bcrypt, and a simple in-memory token store handles session authentication.


➤ **Frontend (login.html, app.html, app.js, styles.css)**
The frontend is plain HTML/CSS/JS — no framework. login.html handles signup and login by calling the Flask /api/auth/* endpoints and saves the returned token to localStorage. app.html is the main single-page application with sections for Dashboard, Workouts, Exercises, Progress, Goals, and Membership. app.js fetches data from the Flask API and renders it dynamically into the DOM. styles.css provides the dark, modern fitness-themed look using the Bebas Neue and Outfit fonts.
