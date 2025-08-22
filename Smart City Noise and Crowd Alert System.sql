-- 1️⃣ Create Database
CREATE DATABASE IF NOT EXISTS urban_monitoring;
USE urban_monitoring;

-- 2️⃣ Zones Table
CREATE TABLE IF NOT EXISTS zones (
  zone_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6)
);

-- 3️⃣ Sensors Table
CREATE TABLE IF NOT EXISTS sensors (
  sensor_id INT AUTO_INCREMENT PRIMARY KEY,
  zone_id INT NOT NULL,
  type ENUM('MICROPHONE','CROWD') NOT NULL,
  model VARCHAR(50),
  installed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) DEFAULT 'ACTIVE',
  FOREIGN KEY (zone_id) REFERENCES zones(zone_id) ON DELETE CASCADE
);

-- 4️⃣ Noise Readings Table
CREATE TABLE IF NOT EXISTS noise_readings (
  reading_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  sensor_id INT NOT NULL,
  ts TIMESTAMP NOT NULL,
  noise_db DECIMAL(5,2),
  FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id) ON DELETE CASCADE,
  INDEX idx_noise_ts(ts)
);

-- 5️⃣ Crowd Readings Table
CREATE TABLE IF NOT EXISTS crowd_readings (
  reading_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  sensor_id INT NOT NULL,
  ts TIMESTAMP NOT NULL,
  people_count INT,
  FOREIGN KEY (sensor_id) REFERENCES sensors(sensor_id) ON DELETE CASCADE,
  INDEX idx_crowd_ts(ts)
);

-- 6️⃣ Alerts Table
CREATE TABLE IF NOT EXISTS alerts (
  alert_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  zone_id INT NOT NULL,
  type VARCHAR(20) NOT NULL,
  message VARCHAR(255),
  level ENUM('INFO','WARN','CRITICAL'),
  FOREIGN KEY (zone_id) REFERENCES zones(zone_id) ON DELETE CASCADE
);

-- 7️⃣ Insert Zones
INSERT INTO zones (zone_id, name, latitude, longitude) VALUES
(1, 'Downtown', 12.9716, 77.5946),
(2, 'Airport Road', 12.9550, 77.7000),
(3, 'Industrial Area', 12.9250, 77.5800)
ON DUPLICATE KEY UPDATE
latitude = VALUES(latitude),
longitude = VALUES(longitude);

-- 8️⃣ Insert Sensors
INSERT INTO sensors (sensor_id, zone_id, type, model) VALUES
(1, 1, 'MICROPHONE', 'NoiseSense-100'),
(2, 1, 'CROWD', 'CrowdCounter-200'),
(3, 2, 'MICROPHONE', 'NoiseSense-110'),
(4, 2, 'CROWD', 'CrowdCounter-210'),
(5, 3, 'MICROPHONE', 'NoiseSense-120'),
(6, 3, 'CROWD', 'CrowdCounter-220')
ON DUPLICATE KEY UPDATE
zone_id = VALUES(zone_id),
type = VALUES(type),
model = VALUES(model);

-- 9️⃣ Insert Noise Readings (recent timestamps for demo)
INSERT IGNORE INTO noise_readings (sensor_id, ts, noise_db) VALUES
(1, NOW() - INTERVAL 10 MINUTE, 65.0),
(1, NOW() - INTERVAL 5 MINUTE, 85.0),
(3, NOW() - INTERVAL 7 MINUTE, 90.0),
(5, NOW() - INTERVAL 3 MINUTE, 75.0);

-- 10️⃣ Insert Crowd Readings (recent timestamps for demo)
INSERT IGNORE INTO crowd_readings (sensor_id, ts, people_count) VALUES
(2, NOW() - INTERVAL 10 MINUTE, 50),
(2, NOW() - INTERVAL 5 MINUTE, 120),
(4, NOW() - INTERVAL 7 MINUTE, 200),
(6, NOW() - INTERVAL 3 MINUTE, 80);

-- 11️⃣ High Noise Zones (last 1 hour)
SELECT z.name AS zone, AVG(n.noise_db) AS avg_noise
FROM noise_readings n
JOIN sensors s ON n.sensor_id = s.sensor_id
JOIN zones z ON s.zone_id = z.zone_id
WHERE n.ts > NOW() - INTERVAL 1 HOUR
GROUP BY z.name
ORDER BY avg_noise DESC;

-- 12️⃣ Crowd Density Spikes (last 30 minutes)
SELECT z.name AS zone, AVG(c.people_count) AS avg_crowd
FROM crowd_readings c
JOIN sensors s ON c.sensor_id = s.sensor_id
JOIN zones z ON s.zone_id = z.zone_id
WHERE c.ts > NOW() - INTERVAL 30 MINUTE
GROUP BY z.name
HAVING avg_crowd > 50;

-- 13️⃣ Generate Noise Alerts
INSERT INTO alerts (zone_id, type, message, level)
SELECT s.zone_id, 'NOISE', 
       CONCAT('High noise detected: ', AVG(n.noise_db), ' dB'),
       'CRITICAL'
FROM noise_readings n
JOIN sensors s ON n.sensor_id = s.sensor_id
GROUP BY s.zone_id
HAVING AVG(n.noise_db) > 60;  -- lowered threshold for demo

-- 14️⃣ Generate Crowd Alerts
INSERT INTO alerts (zone_id, type, message, level)
SELECT s.zone_id, 'CROWD', 
       CONCAT('High crowd detected: ', AVG(c.people_count), ' people'),
       'CRITICAL'
FROM crowd_readings c
JOIN sensors s ON c.sensor_id = s.sensor_id
GROUP BY s.zone_id
HAVING AVG(c.people_count) > 50;  -- lowered threshold for demo

-- 15️⃣ High-Risk Zones (Noise or Crowd)
SELECT z.name AS zone, 
       AVG(n.noise_db) AS avg_noise, 
       AVG(c.people_count) AS avg_crowd
FROM noise_readings n
JOIN crowd_readings c ON n.sensor_id = c.sensor_id
JOIN sensors s ON n.sensor_id = s.sensor_id
JOIN zones z ON s.zone_id = z.zone_id
WHERE n.ts > NOW() - INTERVAL 1 HOUR
  AND c.ts > NOW() - INTERVAL 30 MINUTE
GROUP BY z.name
HAVING avg_noise > 60 OR avg_crowd > 50;

-- 16️⃣ View All Alerts
SELECT * FROM alerts;
