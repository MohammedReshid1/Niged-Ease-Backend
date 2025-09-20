-- Create databases for each service
CREATE DATABASE core_service_db;
CREATE DATABASE notification_service_db;
CREATE DATABASE user_management_db;

-- Grant all privileges on databases
GRANT ALL PRIVILEGES ON DATABASE core_service_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE notification_service_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE user_management_db TO postgres;