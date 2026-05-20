CREATE DATABASE IF NOT EXISTS fittrack;
USE fittrack;


-- ================================================================
--  CREATING TABLES (14 TABLES)
-- ================================================================
-- Dropping tables if tables exits
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS achievements;
DROP TABLE IF EXISTS meal_logs;
DROP TABLE IF EXISTS foods;
DROP TABLE IF EXISTS goals;
DROP TABLE IF EXISTS progress_log;
DROP TABLE IF EXISTS workout_exercises;
DROP TABLE IF EXISTS workouts;
DROP TABLE IF EXISTS exercises;
DROP TABLE IF EXISTS muscle_groups;
DROP TABLE IF EXISTS exercise_categories;
DROP TABLE IF EXISTS memberships;
DROP TABLE IF EXISTS membership_plans;
DROP TABLE IF EXISTS users;

-- Table 1: USERS
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    email          VARCHAR(100) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    full_name      VARCHAR(100) NOT NULL,
    age            INT          CHECK (age > 0 AND age < 120),
    gender         VARCHAR(10)  CHECK (gender IN ('Male','Female','Other')),
    height_cm      DECIMAL(5,2) CHECK (height_cm > 0),
    weight_kg      DECIMAL(5,2) CHECK (weight_kg > 0),
    fitness_level  VARCHAR(20)  DEFAULT 'Beginner'
                   CHECK (fitness_level IN ('Beginner','Intermediate','Advanced')),
    created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP
);
--  SELECT * FROM users;
--  DELETE FROM users WHERE full_name IN ('Aditya Sharma', 'Daksh Patel');


-- Table 2: MEMBERSHIP_PLANS 
CREATE TABLE membership_plans (
    plan_id          INT AUTO_INCREMENT PRIMARY KEY,
    plan_name        VARCHAR(30)  NOT NULL UNIQUE,
    price_per_month  DECIMAL(6,2) NOT NULL CHECK (price_per_month >= 0),
    duration_months  INT          NOT NULL CHECK (duration_months > 0),
    features         TEXT,
    max_goals        INT          DEFAULT 3,
    has_nutrition    TINYINT      DEFAULT 0,
    has_coach_access TINYINT      DEFAULT 0
);


-- Table 3: MEMBERSHIPS
CREATE TABLE memberships (
    membership_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    plan_id        INT NOT NULL,
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'Pending'
                   CHECK (payment_status IN ('Paid','Pending','Failed','Refunded')),
    auto_renew     TINYINT DEFAULT 1,
    amount_paid    DECIMAL(7,2) CHECK (amount_paid >= 0),
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES membership_plans(plan_id),
    CHECK (end_date > start_date)
);


-- Table 4: EXERCISE_CATEGORIES 
CREATE TABLE exercise_categories (
    category_id    INT AUTO_INCREMENT PRIMARY KEY,
    category_name  VARCHAR(50) NOT NULL UNIQUE,
    description    VARCHAR(255)
);


-- Table 5: MUSCLE_GROUPS 
CREATE TABLE muscle_groups (
    muscle_id      INT AUTO_INCREMENT PRIMARY KEY,
    muscle_name    VARCHAR(50) NOT NULL UNIQUE,
    body_region    VARCHAR(30) NOT NULL
                   CHECK (body_region IN ('Upper','Lower','Core','Full Body'))
);


-- Table 6: EXERCISES
CREATE TABLE exercises (
    exercise_id      INT AUTO_INCREMENT PRIMARY KEY,
    exercise_name    VARCHAR(100) NOT NULL UNIQUE,
    category_id      INT NOT NULL,
    muscle_id        INT NOT NULL,
    difficulty       VARCHAR(20) DEFAULT 'Medium'
                     CHECK (difficulty IN ('Easy','Medium','Hard')),
    calories_per_min DECIMAL(5,2),
    description      TEXT,
    FOREIGN KEY (category_id) REFERENCES exercise_categories(category_id),
    FOREIGN KEY (muscle_id)   REFERENCES muscle_groups(muscle_id)
);


-- Table 7: WORKOUTS
CREATE TABLE workouts (
    workout_id     INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    workout_date   DATE NOT NULL,
    duration_min   INT  NOT NULL CHECK (duration_min > 0),
    notes          TEXT,
    total_calories DECIMAL(7,2) DEFAULT 0,
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- Table 8: WORKOUT_EXERCISES (junction for M:N)
CREATE TABLE workout_exercises (
    we_id        INT AUTO_INCREMENT PRIMARY KEY,
    workout_id   INT NOT NULL,
    exercise_id  INT NOT NULL,
    sets         INT CHECK (sets >= 0),
    reps         INT CHECK (reps >= 0),
    weight_kg    DECIMAL(5,2) CHECK (weight_kg >= 0),
    duration_min INT CHECK (duration_min >= 0),
    FOREIGN KEY (workout_id)  REFERENCES workouts(workout_id)  ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES exercises(exercise_id),
    UNIQUE (workout_id, exercise_id)
);


-- Table 9: PROGRESS_LOG
CREATE TABLE progress_log (
    log_id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    log_date       DATE NOT NULL,
    weight_kg      DECIMAL(5,2) CHECK (weight_kg > 0),
    body_fat_pct   DECIMAL(4,2) CHECK (body_fat_pct >= 0 AND body_fat_pct <= 100),
    muscle_mass_kg DECIMAL(5,2),
    notes          TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE (user_id, log_date)
);


-- Table 10: GOALS
CREATE TABLE goals (
    goal_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL,
    goal_type     VARCHAR(30) NOT NULL
                  CHECK (goal_type IN ('Weight Loss','Weight Gain','Muscle Gain','Endurance','Strength','Flexibility')),
    target_value  DECIMAL(7,2) NOT NULL,
    current_value DECIMAL(7,2),
    unit          VARCHAR(20) NOT NULL,
    deadline      DATE NOT NULL,
    status        VARCHAR(20) DEFAULT 'Active'
                  CHECK (status IN ('Active','Achieved','Failed','Cancelled')),
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- Table 11: FOODS
CREATE TABLE foods (
    food_id       INT AUTO_INCREMENT PRIMARY KEY,
    food_name     VARCHAR(100) NOT NULL UNIQUE,
    calories      DECIMAL(6,2) NOT NULL,
    protein_g     DECIMAL(5,2),
    carbs_g       DECIMAL(5,2),
    fats_g        DECIMAL(5,2),
    serving_size  VARCHAR(30)
);


-- Table 12: MEAL_LOGS
CREATE TABLE meal_logs (
    meal_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL,
    food_id       INT NOT NULL,
    meal_type     VARCHAR(20) CHECK (meal_type IN ('Breakfast','Lunch','Dinner','Snack')),
    servings      DECIMAL(4,2) NOT NULL CHECK (servings > 0),
    log_date      DATE NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (food_id) REFERENCES foods(food_id)
);


-- Table 13: ACHIEVEMENTS
CREATE TABLE achievements (
    achievement_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    achievement_name VARCHAR(100) NOT NULL,
    description      TEXT,
    earned_date      DATE NOT NULL,
    badge_level      VARCHAR(20) CHECK (badge_level IN ('Bronze','Silver','Gold','Platinum')),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- Table 14: NOTIFICATIONS
CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    message         VARCHAR(255) NOT NULL,
    notif_type      VARCHAR(30) CHECK (notif_type IN ('Goal','Workout','Achievement','System')),
    is_read         TINYINT DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- ================================================================
-- INDEXES (for queries faster)
-- ================================================================

CREATE INDEX idx_workouts_user_date ON workouts(user_id, workout_date);
SHOW INDEX FROM workouts;

CREATE INDEX idx_progress_user_date ON progress_log(user_id, log_date);
SHOW INDEX FROM progress_log;

CREATE INDEX idx_goals_user_status   ON goals(user_id, status);
SHOW INDEX FROM goals;

CREATE INDEX idx_meal_user_date      ON meal_logs(user_id, log_date);
SHOW INDEX FROM meal_logs;

CREATE INDEX idx_membership_user     ON memberships(user_id, end_date);
SHOW INDEX FROM memberships;

SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'fittrack'
  AND INDEX_NAME LIKE 'idx_%'
ORDER BY TABLE_NAME, INDEX_NAME;


-- ================================================================
-- TRIGGERS (5 TRIGGERS)
-- ================================================================

DELIMITER // --Introducing the DELIMITER

-- Trigger 1: Auto-mark weight loss goals as Achieved when target is reached
CREATE TRIGGER trg_check_weight_goal
AFTER INSERT ON progress_log
FOR EACH ROW
BEGIN
    UPDATE goals
       SET status = 'Achieved'
     WHERE user_id  = NEW.user_id
       AND goal_type = 'Weight Loss'
       AND status   = 'Active'
       AND NEW.weight_kg <= target_value;
END//


-- Trigger 2: Award Bronze badge after 10th workout + send notification
CREATE TRIGGER trg_workout_milestone
AFTER INSERT ON workouts
FOR EACH ROW
BEGIN
    IF (SELECT COUNT(*) FROM workouts WHERE user_id = NEW.user_id) = 10 THEN
        INSERT INTO achievements (user_id, achievement_name, description, earned_date, badge_level)
        VALUES (NEW.user_id, '10 Workouts Completed', 'You completed 10 workouts!', CURDATE(), 'Bronze');

        INSERT INTO notifications (user_id, message, notif_type)
        VALUES (NEW.user_id, 'Achievement unlocked: 10 Workouts!', 'Achievement');
    END IF;
END//


-- Trigger 3: Auto-calculate workout total_calories when an exercise is added
CREATE TRIGGER trg_update_workout_calories
AFTER INSERT ON workout_exercises
FOR EACH ROW
BEGIN
    UPDATE workouts
       SET total_calories = (
           SELECT COALESCE(SUM(e.calories_per_min * we.duration_min), 0)
             FROM workout_exercises we
             JOIN exercises e ON we.exercise_id = e.exercise_id
            WHERE we.workout_id = NEW.workout_id
       )
     WHERE workout_id = NEW.workout_id;
END//


-- Trigger 4: Sync user's profile weight when new progress entry is logged
CREATE TRIGGER trg_sync_user_weight
AFTER INSERT ON progress_log
FOR EACH ROW
BEGIN
    UPDATE users
       SET weight_kg = NEW.weight_kg
     WHERE user_id = NEW.user_id;
END//


-- Trigger 5: Welcome notification when a paid membership is created
CREATE TRIGGER trg_membership_welcome
AFTER INSERT ON memberships
FOR EACH ROW
BEGIN
    IF NEW.payment_status = 'Paid' THEN
        INSERT INTO notifications (user_id, message, notif_type)
        SELECT NEW.user_id,
               CONCAT('Welcome to ', mp.plan_name, '! Your membership is active until ', NEW.end_date),
               'System'
          FROM membership_plans mp
         WHERE mp.plan_id = NEW.plan_id;
    END IF;
END//


DELIMITER ; -- Ending the DELIMITER

-- To see all the triggers
SHOW TRIGGERS FROM fittrack;


-- ================================================================
-- INSERTING DATAS INTO THE TABLES CREATED (SEED)
-- ================================================================

-- Exercise Categories Table
INSERT INTO exercise_categories (category_name, description) VALUES
('Cardio',      'Cardiovascular endurance training'),
('Strength',    'Resistance and weight training'),
('Flexibility', 'Stretching and mobility'),
('HIIT',        'High Intensity Interval Training'),
('Yoga',        'Mind-body practice with poses');
SELECT * FROM exercise_categories;


-- Muscle Groups Table
INSERT INTO muscle_groups (muscle_name, body_region) VALUES
('Chest',     'Upper'),
('Back',      'Upper'),
('Shoulders', 'Upper'),
('Arms',      'Upper'),
('Legs',      'Lower'),
('Glutes',    'Lower'),
('Abs',       'Core'),
('Full Body', 'Full Body'),
('Cardio',    'Full Body');
SELECT * FROM muscle_groups;


-- Exercises Table
INSERT INTO exercises (exercise_name, category_id, muscle_id, difficulty, calories_per_min, description) VALUES
('Running',          1, 9, 'Medium', 11.5, 'Outdoor or treadmill running'),
('Cycling',          1, 5, 'Easy',   8.0,  'Stationary or road cycling'),
('Jump Rope',        1, 9, 'Medium', 12.0, 'Skipping rope cardio'),
('Bench Press',      2, 1, 'Hard',   6.0,  'Barbell chest press'),
('Deadlift',         2, 2, 'Hard',   7.5,  'Compound back exercise'),
('Squats',           2, 5, 'Medium', 7.0,  'Lower body strength'),
('Pull-ups',         2, 2, 'Hard',   8.0,  'Bodyweight back exercise'),
('Push-ups',         2, 1, 'Easy',   5.5,  'Bodyweight chest exercise'),
('Bicep Curls',      2, 4, 'Easy',   4.0,  'Isolation arm exercise'),
('Shoulder Press',   2, 3, 'Medium', 5.5,  'Overhead pressing'),
('Plank',            3, 7, 'Medium', 3.0,  'Core stability hold'),
('Crunches',         2, 7, 'Easy',   4.5,  'Abdominal exercise'),
('Yoga Flow',        5, 8, 'Easy',   4.0,  'Vinyasa yoga sequence'),
('Burpees',          4, 8, 'Hard',   13.5, 'Full body HIIT'),
('Mountain Climbers',4, 7, 'Medium', 10.0, 'Cardio core exercise'),
('Lunges',           2, 5, 'Medium', 6.0,  'Single leg strength'),
('Hip Thrusts',      2, 6, 'Medium', 5.0,  'Glute activation'),
('Stretching',       3, 8, 'Easy',   2.5,  'General flexibility');
SELECT * FROM exercises;


-- Users Table
INSERT INTO users (username, email, password_hash, full_name, age, gender, height_cm, weight_kg, fitness_level, created_at) VALUES
('alex_p',   'alex@fittrack.com',   '$2b$10$demoHashForAlex000000000000000000000000000000000', 'Alex Patel',     28, 'Male',   178.0, 78.5, 'Intermediate',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 90 DAY), '08:14:22')),
('sara_k',   'sara@fittrack.com',   '$2b$10$demoHashForSara000000000000000000000000000000000', 'Sara Kim',       25, 'Female', 165.0, 60.2, 'Beginner',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 75 DAY), '13:42:09')),
('mike_r',   'mike@fittrack.com',   '$2b$10$demoHashForMike000000000000000000000000000000000', 'Mike Rodriguez', 35, 'Male',   182.0, 92.0, 'Advanced',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 120 DAY),'19:55:48')),
('priya_s',  'priya@fittrack.com',  '$2b$10$demoHashForPriya00000000000000000000000000000000', 'Priya Sharma',   30, 'Female', 160.0, 55.5, 'Intermediate',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 45 DAY), '11:08:30'));
  SELECT * FROM users; 
   

-- Membership Plans Table
INSERT INTO membership_plans (plan_name, price_per_month, duration_months, features, max_goals, has_nutrition, has_coach_access) VALUES
('Free',           0.00,  1,  'Basic workout & progress tracking, 3 goals max',                              3,  0, 0),
('Premium',        9.99,  1,  'Unlimited goals, full nutrition tracking, all exercises, achievements',       99, 1, 0),
('Pro',            19.99, 1,  'Everything in Premium + 1-on-1 coach access, custom plans, priority support', 99, 1, 1),
('Annual Premium', 7.99,  12, 'Premium plan billed annually (save 20%)',                                     99, 1, 0),
('Annual Pro',     15.99, 12, 'Pro plan billed annually (save 20%)',                                         99, 1, 1);
  SELECT * FROM membership_plans; 
  

-- Memberships Table
INSERT INTO memberships (user_id, plan_id, start_date, end_date, payment_status, auto_renew, amount_paid, created_at) VALUES
(1, 2, DATE_SUB(CURDATE(), INTERVAL 15 DAY), DATE_ADD(CURDATE(), INTERVAL 15 DAY),  'Paid', 1, 9.99,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 15 DAY), '09:23:14')),  -- Alex  – mid-morning UAE
(2, 1, DATE_SUB(CURDATE(), INTERVAL 30 DAY), DATE_ADD(CURDATE(), INTERVAL 335 DAY), 'Paid', 0, 0.00,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 30 DAY), '14:47:32')),  -- Sara  – early afternoon UAE
(3, 5, DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_ADD(CURDATE(), INTERVAL 305 DAY), 'Paid', 1, 191.88,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 60 DAY), '21:08:55')),  -- Mike  – evening UAE
(4, 2, DATE_SUB(CURDATE(), INTERVAL 5 DAY),  DATE_ADD(CURDATE(), INTERVAL 25 DAY),  'Paid', 1, 9.99,
       TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 5 DAY),  '07:35:51'));  -- Priya – early morning UAE
SELECT * FROM memberships; 

-- Workouts Table
INSERT INTO workouts (user_id, workout_date, duration_min, notes, created_at) VALUES
(1, DATE_SUB(CURDATE(), INTERVAL 7 DAY), 60, 'Morning push day',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '06:42:18')),
(1, DATE_SUB(CURDATE(), INTERVAL 5 DAY), 45, 'Cardio session',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 5 DAY), '18:15:44')),
(1, DATE_SUB(CURDATE(), INTERVAL 2 DAY), 75, 'Heavy leg day',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '07:05:09')),
(2, DATE_SUB(CURDATE(), INTERVAL 6 DAY), 30, 'Beginner full-body',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 6 DAY), '17:28:33')),
(2, DATE_SUB(CURDATE(), INTERVAL 3 DAY), 40, 'Yoga + light cardio',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 3 DAY), '08:54:07')),
(3, DATE_SUB(CURDATE(), INTERVAL 4 DAY), 90, 'Strength training',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 4 DAY), '20:11:26')),
(3, DATE_SUB(CURDATE(), INTERVAL 1 DAY), 60, 'HIIT session',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '19:47:52')),
(4, DATE_SUB(CURDATE(), INTERVAL 2 DAY), 50, 'Core focus',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '12:33:41'));
SELECT * FROM workouts; 


-- Workout Exercises Table
INSERT INTO workout_exercises (workout_id, exercise_id, sets, reps, weight_kg, duration_min) VALUES
(1, 4,  4, 8,  70, 15),
(1, 8,  3, 15, 0,  10),
(1, 9,  3, 12, 15, 10),
(2, 1,  0, 0,  0,  30),
(2, 3,  0, 0,  0,  10),
(3, 5,  4, 6,  120, 20),
(3, 6,  4, 10, 80,  20),
(3, 16, 3, 12, 20,  15),
(4, 8,  2, 10, 0,   8),
(4, 11, 2, 0,  0,   5),
(5, 13, 0, 0,  0,   25),
(6, 4,  5, 5,  90,  20),
(6, 5,  5, 5,  140, 25),
(7, 14, 5, 15, 0,   15),
(7, 15, 5, 20, 0,   15),
(8, 11, 3, 0,  0,   10),
(8, 12, 3, 25, 0,   10);
SELECT * FROM workout_exercises;


-- Progress logs Table
INSERT INTO progress_log (user_id, log_date, weight_kg, body_fat_pct, notes) VALUES
(1, DATE_SUB(CURDATE(), INTERVAL 30 DAY), 80.5, 18.0, 'Starting weight'),
(1, DATE_SUB(CURDATE(), INTERVAL 15 DAY), 79.2, 17.5, 'Down 1.3kg'),
(1, DATE_SUB(CURDATE(), INTERVAL 1 DAY),  78.5, 17.0, 'Steady progress'),
(2, DATE_SUB(CURDATE(), INTERVAL 20 DAY), 62.0, 24.0, 'Beginning journey'),
(2, DATE_SUB(CURDATE(), INTERVAL 1 DAY),  60.2, 23.0, NULL),
(3, DATE_SUB(CURDATE(), INTERVAL 30 DAY), 89.0, 15.0, 'Bulking phase'),
(3, DATE_SUB(CURDATE(), INTERVAL 1 DAY),  92.0, 15.5, 'Gaining muscle'),
(4, DATE_SUB(CURDATE(), INTERVAL 1 DAY),  55.5, 22.0, 'Maintenance');
SELECT * FROM progress_log;


-- Goals Table 
INSERT INTO goals (user_id, goal_type, target_value, current_value, unit, deadline, status) VALUES
(1, 'Weight Loss',  75.0,  78.5, 'kg',   DATE_ADD(CURDATE(), INTERVAL 60 DAY), 'Active'),
(1, 'Strength',     100.0, 70.0, 'kg',   DATE_ADD(CURDATE(), INTERVAL 90 DAY), 'Active'),
(2, 'Endurance',    30.0,  10.0, 'min',  DATE_ADD(CURDATE(), INTERVAL 45 DAY), 'Active'),
(3, 'Muscle Gain',  95.0,  92.0, 'kg',   DATE_ADD(CURDATE(), INTERVAL 90 DAY), 'Active'),
(4, 'Flexibility',  100.0, 60.0, 'pts',  DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Active');
SELECT * FROM goals;


-- Foods Table
INSERT INTO foods (food_name, calories, protein_g, carbs_g, fats_g, serving_size) VALUES
('Chicken Breast',  165, 31, 0,   3.6, '100g'),
('Brown Rice',      215, 5,  45,  1.8, '1 cup'),
('Banana',          105, 1.3,27,  0.4, '1 medium'),
('Greek Yogurt',    100, 17, 6,   0.7, '170g'),
('Almonds',         164, 6,  6,   14,  '28g'),
('Oatmeal',         150, 5,  27,  3,   '1 cup'),
('Eggs',            72,  6,  0.4, 5,   '1 large'),
('Salmon',          208, 22, 0,   13,  '100g');
SELECT * FROM foods;


-- Meal logs Table
INSERT INTO meal_logs (user_id, food_id, meal_type, servings, log_date) VALUES
(1, 6, 'Breakfast', 1.0, CURDATE()),
(1, 7, 'Breakfast', 2.0, CURDATE()),
(1, 1, 'Lunch',     1.5, CURDATE()),
(2, 4, 'Breakfast', 1.0, CURDATE()),
(2, 3, 'Snack',     1.0, CURDATE());
SELECT * FROM meal_logs;


-- Achievements Table
INSERT INTO achievements (user_id, achievement_name, description, earned_date, badge_level) VALUES
(1, 'First Workout',     'Logged your first workout!',         DATE_SUB(CURDATE(), INTERVAL 7 DAY), 'Bronze'),
(1, 'Consistency King',  '5 workouts in one week',             DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'Silver'),
(3, 'Heavy Lifter',      'Deadlifted over 140kg',              DATE_SUB(CURDATE(), INTERVAL 4 DAY), 'Gold');
SELECT * FROM achievements;


-- Notifications Table
INSERT INTO notifications (user_id, message, notif_type) VALUES
(1, 'You are 3.5kg away from your weight goal!', 'Goal'),
(2, 'Time for your scheduled workout',           'Workout'),
(3, 'New achievement unlocked!',                 'Achievement');
SELECT * FROM notifications;


SHOW TABLES;


-- ================================================================
-- VIEWS
-- ================================================================

-- User Dashboard View
DROP VIEW IF EXISTS v_user_dashboard;
CREATE VIEW v_user_dashboard AS
SELECT  u.user_id,
        u.full_name,
        u.weight_kg,
        ROUND(u.weight_kg / ((u.height_cm/100.0)*(u.height_cm/100.0)), 2) AS bmi,
        (SELECT COUNT(*) FROM workouts w WHERE w.user_id = u.user_id) AS total_workouts,
        (SELECT COUNT(*) FROM goals g WHERE g.user_id = u.user_id AND g.status = 'Active') AS active_goals,
        (SELECT COUNT(*) FROM achievements a WHERE a.user_id = u.user_id) AS badges
FROM    users u;
SELECT * FROM v_user_dashboard; -- to view user dashboard

-- Workout Details View
DROP VIEW IF EXISTS v_workout_details;
CREATE VIEW v_workout_details AS
SELECT  w.workout_id,
        u.full_name,
        w.workout_date,
        w.duration_min,
        w.total_calories,
        COUNT(we.we_id) AS exercise_count
FROM    workouts w
JOIN    users u ON w.user_id = u.user_id
LEFT JOIN workout_exercises we ON w.workout_id = we.workout_id
GROUP BY w.workout_id, u.full_name, w.workout_date, w.duration_min, w.total_calories;
SELECT * FROM v_workout_details; -- to view workout details



-- ================================================================
-- FUNCTION & PROCEDURE
-- ================================================================
DROP FUNCTION  IF EXISTS fn_calculate_bmi;
DROP PROCEDURE IF EXISTS sp_user_workout_summary;

DELIMITER //

-- ----------------------------------------------------------------
-- FUNCTION: fn_calculate_bmi
-- ----------------------------------------------------------------
CREATE FUNCTION fn_calculate_bmi (
    weight_kg DECIMAL(5,2),
    height_cm DECIMAL(5,2)
)
RETURNS DECIMAL(5,2)
NO SQL
BEGIN
    DECLARE bmi DECIMAL(5,2);
    SET bmi = weight_kg / ((height_cm / 100) * (height_cm / 100));
    RETURN ROUND(bmi, 2);
END //
SELECT fn_calculate_bmi(70, 175); -- weight = 70 kg and height = 175 cm


-- ----------------------------------------------------------------
-- PROCEDURE: sp_user_workout_summary
-- ----------------------------------------------------------------
CREATE PROCEDURE sp_user_workout_summary (
    IN p_user_id INT
)
BEGIN
    SELECT  user_id,
            COUNT(*)            AS total_workouts,
            SUM(duration_min)   AS total_minutes,
            SUM(total_calories) AS total_calories
    FROM    workouts
    WHERE   user_id = p_user_id
    GROUP BY user_id;
END //
CALL sp_user_workout_summary(1); -- calling workout summary for user Alex

DELIMITER ;




-- ================================================================
-- QUERIES
-- ================================================================

-- ----- BASIC QUERIES -----
-- Q1: List all users with BMI calculated (using fn_calculate_bmi)
SELECT  user_id, full_name, weight_kg, height_cm,
        fn_calculate_bmi(weight_kg, height_cm) AS bmi
FROM    users
ORDER BY bmi DESC;


-- Q2: Count exercises by category
SELECT  ec.category_name,
        COUNT(e.exercise_id) AS total_exercises
FROM    exercise_categories ec
LEFT JOIN exercises e ON ec.category_id = e.category_id
GROUP BY ec.category_name;


-- ----- JOIN QUERIES -----
-- Q3: All workouts with user details and exercise count
SELECT  u.full_name, w.workout_date, w.duration_min,
        COUNT(we.exercise_id) AS exercises_done,
        w.total_calories
FROM    users u
JOIN    workouts w           ON u.user_id      = w.user_id
LEFT JOIN workout_exercises we ON w.workout_id = we.workout_id
GROUP BY w.workout_id, u.full_name, w.workout_date, w.duration_min, w.total_calories
ORDER BY w.workout_date DESC;


-- Q4: Detailed workout breakdown (5-table JOIN)
SELECT  u.full_name, w.workout_date, e.exercise_name,
        ec.category_name, mg.muscle_name,
        we.sets, we.reps, we.weight_kg, we.duration_min
FROM    workouts w
JOIN    users u                ON w.user_id      = u.user_id
JOIN    workout_exercises we   ON w.workout_id   = we.workout_id
JOIN    exercises e            ON we.exercise_id = e.exercise_id
JOIN    exercise_categories ec ON e.category_id  = ec.category_id
JOIN    muscle_groups mg       ON e.muscle_id    = mg.muscle_id
ORDER BY w.workout_date DESC, e.exercise_name;


-- ----- NESTED QUERIES (Subqueries) -----
-- Q5: Users heavier than the average
SELECT  full_name, weight_kg
FROM    users
WHERE   weight_kg > (SELECT AVG(weight_kg) FROM users);


-- Q6: Exercises that have NEVER been performed
SELECT  exercise_name
FROM    exercises
WHERE   exercise_id NOT IN (SELECT exercise_id FROM workout_exercises);


-- Q7: Users with at least one Active goal AND at least one workout
SELECT  full_name
FROM    users
WHERE   user_id IN (SELECT user_id FROM goals WHERE status = 'Active')
  AND   user_id IN (SELECT user_id FROM workouts);


-- Q8: Top 3 most-used exercises
SELECT e.exercise_name, COUNT(*) AS times_used
FROM exercises e
JOIN workout_exercises w ON w.exercise_id = e.exercise_id
GROUP BY e.exercise_id, e.exercise_name
ORDER BY times_used DESC
LIMIT 3;


-- ----- CORRELATED SUBQUERIES -----
-- Q9: For each user, their most recent workout date
SELECT  u.full_name,
        (SELECT MAX(w.workout_date)
           FROM workouts w
          WHERE w.user_id = u.user_id) AS last_workout
FROM    users u;


-- Q10: Users who logged more workouts than the overall average
SELECT  u.full_name,
        (SELECT COUNT(*) FROM workouts w WHERE w.user_id = u.user_id) AS workout_count
FROM    users u
WHERE   (SELECT COUNT(*) FROM workouts w WHERE w.user_id = u.user_id) >
        (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM workouts GROUP BY user_id) AS sub);



-- Q11: For each exercise, its highest weight lifted
SELECT  e.exercise_name,
        (SELECT MAX(we.weight_kg)
           FROM workout_exercises we
          WHERE we.exercise_id = e.exercise_id) AS max_weight
FROM    exercises e
WHERE   EXISTS (SELECT 1 FROM workout_exercises we WHERE we.exercise_id = e.exercise_id);


-- Q12: Users whose latest weight is lower than their first logged weight
SELECT  u.full_name
FROM    users u
WHERE   EXISTS (
        SELECT 1
          FROM progress_log p1
         WHERE p1.user_id = u.user_id
           AND p1.log_date = (SELECT MAX(log_date) FROM progress_log WHERE user_id = u.user_id)
           AND p1.weight_kg < (SELECT weight_kg FROM progress_log
                                WHERE user_id = u.user_id
                                ORDER BY log_date ASC LIMIT 1)
        );


-- ----- AGGREGATE & GROUP BY -----
-- Q13: Weekly workout summary per user (with month shown)
SELECT  u.full_name,
        DATE_FORMAT(w.workout_date, '%Y-%u') AS week,
        DATE_FORMAT(w.workout_date, '%M %Y') AS month,
        COUNT(*)              AS workout_count,
        SUM(w.duration_min)   AS total_minutes,
        SUM(w.total_calories) AS calories_burned
FROM    users u
JOIN    workouts w ON u.user_id = w.user_id
GROUP BY u.user_id, u.full_name, week, month
ORDER BY u.full_name, week DESC;

-- Q14: Most popular muscle group across all users
SELECT  mg.muscle_name,
        COUNT(*) AS times_trained
FROM    workout_exercises we
JOIN    exercises e      ON we.exercise_id = e.exercise_id
JOIN    muscle_groups mg ON e.muscle_id    = mg.muscle_id
GROUP BY mg.muscle_id, mg.muscle_name
ORDER BY times_trained DESC;


-- ----- SET OPERATIONS -----
-- Q15: Users with goals UNION users with workouts
SELECT user_id, full_name FROM users WHERE user_id IN (SELECT user_id FROM goals)
UNION
SELECT user_id, full_name FROM users WHERE user_id IN (SELECT user_id FROM workouts);

-- Badges earned by each user (Join Query)
-- SELECT u.full_name, a.achievement_name, a.badge_level, a.earned_date
-- FROM users u
-- JOIN achievements a ON u.user_id = a.user_id
-- ORDER BY u.full_name, a.earned_date;


