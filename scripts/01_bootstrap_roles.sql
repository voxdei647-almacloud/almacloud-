-- Bootstrap de roles para ALMA CLOUD
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'alma_migrator') THEN
        CREATE ROLE alma_migrator WITH LOGIN PASSWORD 'migrator_secret_dev';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'alma_app') THEN
        CREATE ROLE alma_app WITH LOGIN PASSWORD 'app_secret_dev';
    END IF;
END $$;

GRANT ALL PRIVILEGES ON DATABASE postgres TO alma_migrator;
GRANT USAGE ON SCHEMA public TO alma_app;
