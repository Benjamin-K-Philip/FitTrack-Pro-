# FitTrack Pro

## Description
A full-stack health and fitness tracker powered by a 14-table MySQL database, a Python Flask backend, and an HTML/CSS/JavaScript frontend. Demonstrates normalized schema design, foreign keys, indexes, triggers, stored functions, procedures, views, and advanced SQL queries. Users can log workouts, track progress, set goals, earn achievements, and manage memberships.

---

## How the Code Works <br>
The FitTrack Pro system is built on a three-layer architecture: a MySQL database (data layer), a Flask Python backend (logic and API layer), and an HTML/JS frontend (presentation layer). The database is the heart of the project — every action a user takes on the website ultimately translates into SQL operations against the fittrack database.

➤ **MySQL Database (fittrack_database_mysql_func_and_proc.sql)**
This single SQL file builds the entire database and contains every structural element of the project. It is organized into clearly labelled sections:

 - **Database Creation:** Begins with CREATE DATABASE IF NOT EXISTS fittrack and USE fittrack to ensure a clean working environment. Each table is dropped (with DROP TABLE IF EXISTS) in reverse dependency order before being created, so the script can be re-run safely.
  
 - **14 Tables (Normalized Schema):** <br>
The schema is fully normalized with proper primary keys, foreign keys, CHECK constraints, UNIQUE constraints, and ON DELETE CASCADE rules. Following are the tables are:
   - **users:** Stores account info, demographics (age, gender, height, weight), and a bcrypt password_hash.
   - **membership_plans and memberships:** Model the subscription system (Free, Premium, Pro, Annual variants).
   - **exercise_categories, muscle_groups, and exercises:** A normalized exercise library where each exercise belongs to one category and targets one muscle group.
   - **workouts and workout_exercises:** The latter is a junction table that resolves the many-to-many relationship between workouts and exercises (one workout has many exercises, and one exercise can appear in many workouts), with extra columns for sets, reps, weight, and duration.
   - **progress_log:** Tracks weight, body fat percentage, and muscle mass over time, with a UNIQUE (user_id, log_date) constraint to prevent duplicate entries on the same day.
   - **goals:** Fitness goals with type, target value, deadline, and status.
   - **foods and meal_logs:** Basic nutrition tracking module.
   - **achievements:** Badges (Bronze/Silver/Gold/Platinum) awarded to users. 
   - **notifications:** System messages for goals, workouts, achievements, and announcements.


 - **Indexes:** <br> 
Five composite indexes are created on the most frequently queried columns (user_id + date combinations on workouts, progress_log, goals, meal_logs, and memberships) to speed up the dashboard and history queries.


 - **5 Triggers:**  <br>
Automate side-effects so that the database stays consistent without the application layer having to remember every rule. The DELIMITER // directive is used so multi-statement trigger bodies can be parsed correctly. Following are the triggers:

   - **trg_check_weight_goal:** After a new progress_log row is inserted, automatically marks any active Weight Loss goal as 'Achieved' if the new weight has hit the target.
   - **trg_workout_milestone:** After a workout is inserted, checks whether the user has reached exactly 10 workouts. If so, it inserts a Bronze badge into achievements and a congratulatory message into notifications.
   - **trg_update_workout_calories:** After an exercise is added to a workout, automatically recalculates and updates the workout's total_calories based on each exercise's calories_per_min and duration_min.
   - **trg_sync_user_weight:** Keeps the users.weight_kg profile field synced with the latest progress_log entry.
   - **trg_membership_welcome:** When a paid membership is created, inserts a personalized welcome notification that includes the plan name and end date.


 - **2 Views:** <br>
 Pre-computed virtual tables that simplify dashboard into the following queries:
   - **v_user_dashboard:** Aggregates each user's BMI, total workouts, active goals, and badge count into one row.
   - **v_workout_details:** Joins workouts with their user and counts the exercises per workout.


 - **Stored Function — fn_calculate_bmi:** <br>
Takes weight (kg) and height (cm) as arguments and returns the BMI rounded to two decimal places using the standard formula weight / (height_m)².

 - **Stored Procedure — sp_user_workout_summary:** <br>
Accepts a user_id and returns the user's total workouts, total minutes, and total calories burned.

 - **Seed Data:** <br>
Pre-populates every table with sample records — 4 users (Alex, Sara, Mike, Priya), 18 exercises, 5 membership plans, sample workouts, progress logs, goals, foods, meal logs, achievements, and notifications — so the application is immediately demoable.

 - **15 Sample Queries:** <br> 
 The end of the file contains organized query examples covering basic SELECTs, multi-table JOINs (including a 5-table join), nested subqueries, correlated subqueries, aggregate functions with GROUP BY, and set operations (UNION).

<br>

➤ **Python Backend (build_db_mysql.py, set_passwords.py, app.py)** <br>
The Python files act as the bridge between the SQL file and the live application. They all use the mysql-connector-python library to talk to MySQL.

- **build_db_mysql.py — The Database Builder:** <br>
The python script does the following: 
 1. Connects to the local MySQL server using credentials in DB_CONFIG.
 2. Checks if the fittrack database already exists and asks for confirmation before rebuilding.
 3. Reads fittrack_database_mysql_func_and_proc.sql from disk and feeds it to a custom parse_statements() function, which intelligently splits the file into individual statements while respecting DELIMITER // directives needed for the triggers, function, and procedure.
 4. Executes each statement through the MySQL connector cursor.
 5. Prints a summary showing the row count of every table, plus the names of all triggers and views that were created.


 - **set_passwords.py — Real Password Setup:** <br>
 The seed users in the SQL file have placeholder password hashes. This helper script connects to the fittrack database, generates a real bcrypt hash for the password password123, and updates every seed user's password_hash column with it — so the four demo accounts (alex, sara, mike, priya) can actually log in.
 
 - **app.py — The Flask API Server:** <br>
Exposes a RESTful API that the frontend calls. It uses mysql.connector to open a database connection per request (via Flask's g object), runs parameterized SQL queries against the fittrack database, and returns JSON. Routes include /api/auth/login, /api/auth/signup, /api/workouts, /api/exercises, /api/goals, /api/progress, /api/memberships, and dashboard endpoints. Passwords are hashed and verified with bcrypt, and a simple in-memory token store handles session authentication.

<br>

➤ **Frontend (login.html, app.html, app.js, styles.css)**
 - Built with plain HTML, CSS, and JavaScript — no framework used.
 - **login.html:** Handles signup and login by calling the Flask /api/auth/* endpoints and saves the returned token to localStorage.
 - **app.html:** The main single-page application with sections for Dashboard, Workouts, Exercises, Progress, Goals, and Membership.
 - **app.js:** Fetches data from the Flask API and renders it dynamically into the DOM.
 - **styles.css:** Provides the dark, modern fitness-themed look using the Bebas Neue and Outfit fonts.

---


## Features <br>
 - Complete user authentication with bcrypt-hashed passwords (signup, login, logout, token-based sessions).
 - **Workout logging** with multiple exercises per workout, including sets, reps, weight, and duration.
 - **Exercise library** searchable by name, filterable by category and muscle group.
 - **Progress tracking** — log weight, body fat percentage, and muscle mass over time, with auto-sync to the user profile.
 - **Goal setting** with six goal types (Weight Loss, Weight Gain, Muscle Gain, Endurance, Strength, Flexibility) and auto-achievement detection via triggers.
 - **Membership plans** — Free, Premium, Pro, and annual variants, with feature gating (max goals, nutrition tracking, coach access).
 - **Achievements & badges** (Bronze, Silver, Gold, Platinum) awarded automatically by triggers.
 - **Notifications** for goals, workouts, achievements, and system messages.
 - **Live dashboard** with auto-calculated BMI (using the fn_calculate_bmi SQL function), total workouts, active goals, badge count, and a weekly activity chart.
 - **Leaderboard** ranking users by workout count.
 - Demonstrates **15 SQL queries** covering joins, subqueries, correlated subqueries, aggregates, and set operations.
- Demonstrates **5 triggers, 2 views, 1 stored function, and 1 stored procedure**.

---


## Project Structure <br>
 - **database/ :** Contains the main SQL script.
   - **fittrack_database_mysql_func_and_proc.sql:** Full schema, indexes, triggers, views, function, procedure, seed data, and sample queries.
   - **build_db_mysql.py:** Python script that parses and executes the SQL file to build the fittrack database.
   - **set_passwords.py:** Utility script that replaces placeholder password hashes with real bcrypt hashes for the seed users.


 - **backend/ :** Flask API server.
   - **app.py:** Flask application with all REST API endpoints, authentication logic, and MySQL connection handling.


- **frontend/ :** Static web client. 
   - **login.html:** Signup and login page.
   - **app.html:** Main single page application shell with all sections (dashboard, workouts, exercises, progress, goals, membership).
   - **app.js:** Client-side logic that calls the Flask API and renders data.
   - **styles.css:** Full styling for the app and login pages.

 ---


 ## Entity Relationship (ER) Diagram
 <img width="1171" height="1251" alt="refer this-with triggers and indexesER Diagram-fittrack_database_mysql-func and proc" src="https://github.com/user-attachments/assets/c29b3ff2-af15-49e7-a6ec-54605ab54934" />

 ---

 ## Outputs
 <img width="1366" height="720" alt="Screenshot (9904)" src="https://github.com/user-attachments/assets/494829e0-378e-48f3-8821-5debd2f2289c" />
<br>
<img width="1366" height="720" alt="Screenshot (9905)" src="https://github.com/user-attachments/assets/b3df7b9a-38d8-4e45-bca2-a4cc3a3eb042" />
<br>
<img width="1366" height="718" alt="Screenshot (9906)" src="https://github.com/user-attachments/assets/1109e2e5-794e-4c04-af2b-de0faf2ca297" />
<br>
<img width="1366" height="722" alt="Screenshot (9922)" src="https://github.com/user-attachments/assets/e4682e48-c417-4054-9192-8c3588622930" />
<br>
<img width="1366" height="720" alt="Screenshot (9908)" src="https://github.com/user-attachments/assets/b85665c3-2fc3-429a-b00b-f2456fab381a" />
<br>
<img width="1366" height="720" alt="Screenshot (9909)" src="https://github.com/user-attachments/assets/e30b52dd-f0e3-4a3b-864c-634d521f00ea" />
<br>
<img width="1366" height="720" alt="Screenshot (9911)" src="https://github.com/user-attachments/assets/5f09bdef-9d6b-459c-b13f-5aeeedb05d88" />
<br>
<img width="1366" height="724" alt="Screenshot (9912)" src="https://github.com/user-attachments/assets/e80ae660-6616-4555-a69c-38c8df1cb9c6" />
<br>
<img width="1366" height="722" alt="Screenshot (9913)" src="https://github.com/user-attachments/assets/d21b92b3-ed05-4e89-932b-4368fa29268c" />
<br>
<img width="1366" height="720" alt="Screenshot (9914)" src="https://github.com/user-attachments/assets/1a69c57f-7dc1-4bd2-9817-6b6b44e69ef5" />
<br>
<img width="1366" height="722" alt="Screenshot (9915)" src="https://github.com/user-attachments/assets/864dbba6-63b3-436d-a3e5-05d26edcc495" />
<br>
<img width="1366" height="720" alt="Screenshot (9916)" src="https://github.com/user-attachments/assets/dadd290c-1cbe-48fa-abc9-f52e747b1335" />
<br>
<img width="1366" height="720" alt="Screenshot (9917)" src="https://github.com/user-attachments/assets/2d9cadcf-bcbc-4ef5-a2c2-b5207abb508c" />
<br>
<img width="1366" height="722" alt="Screenshot (9918)" src="https://github.com/user-attachments/assets/22c3cc15-f2aa-4657-b94f-6667db8633e9" />
<br>
<img width="1366" height="726" alt="Screenshot (9919)" src="https://github.com/user-attachments/assets/6eb1bdad-c63e-42fd-87c9-3297ea637636" />
<br>
<img width="1366" height="720" alt="Screenshot (9920)" src="https://github.com/user-attachments/assets/6290641c-e8e3-493a-a07a-2bcf352033e8" />
<br>
<img width="1366" height="724" alt="Screenshot (9921)" src="https://github.com/user-attachments/assets/071e1350-a294-4cbd-bf70-16150b7099c7" />

---


## Setup Instructions <br>
  1. Make sure MySQL Server is running locally and **update the password in DB_CONFIG inside build_db_mysql.py, set_passwords.py, and app.py to match your MySQL root password**.
  2. Install Python dependencies: pip install mysql-connector-python flask bcrypt.
  3. Run python build_db_mysql.py to build the fittrack database with all tables, triggers, views, function, procedure, and seed data.
  4. Run python set_passwords.py to set real bcrypt passwords for the seed users.
  5. Run python app.py to start the Flask server.
  6. Open the URL in your browser and log in with any seed account (e.g. alex@fittrack.com / password123) or create a new account.
