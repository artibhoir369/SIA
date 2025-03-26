#!/bin/bash

# Default to 1 backend instance if not specified
N_BACKENDS=${1:-1}

# Stop and remove any existing containers
docker-compose down

# Start all containers in the background
docker-compose up -d

# Wait for MySQL master to be fully ready
echo "Waiting for MySQL master to be ready..."
until docker exec sia_master_mysql mysql -u sia_username -psia_password -e "SHOW DATABASES;" >/dev/null 2>&1; do
  echo "Waiting for MySQL master to be ready..."
  sleep 2
done
echo "MySQL is ready!"

echo "Granting necessary privileges to MySQL user for replication and backup..."
docker exec sia_master_mysql mysql -u root -psia_root_password -e "
  GRANT REPLICATION CLIENT, REPLICATION SLAVE, PROCESS ON *.* TO 'sia_username'@'%';
  GRANT SHOW DATABASES ON *.* TO 'sia_username'@'%';
  GRANT SELECT, LOCK TABLES ON *.* TO 'sia_username'@'%';
  FLUSH PRIVILEGES;
"
echo "MySQL privileges granted."

# Ensure the same on the slave container if needed
docker exec sia_slave_mysql mysql -u root -psia_root_password -e "
  GRANT REPLICATION SLAVE, SUPER ON *.* TO 'sia_username'@'%';
  FLUSH PRIVILEGES;
"

echo "MySQL privileges granted."

# Start replication for the slave instance
echo "Setting up MySQL replication..."

# Dynamically get the current master log file and position
MASTER_LOG_FILE=$(docker exec sia_master_mysql mysql -u sia_username -psia_password -e "SHOW MASTER STATUS\G" | grep "File:" | awk '{print $2}')
MASTER_LOG_POS=$(docker exec sia_master_mysql mysql -u sia_username -psia_password -e "SHOW MASTER STATUS\G" | grep "Position:" | awk '{print $2}')

# Now run the CHANGE MASTER TO command with the values
docker exec sia_slave_mysql mysql -u sia_username -psia_password -e "
  STOP SLAVE;
  CHANGE MASTER TO MASTER_HOST='sia_master_mysql', MASTER_USER='sia_username', MASTER_PASSWORD='sia_password', MASTER_LOG_FILE='$MASTER_LOG_FILE', MASTER_LOG_POS=$MASTER_LOG_POS;
  START SLAVE;
"

echo "Replication setup completed."


# Wait for the replication to start
sleep 5

# Run the migration command once (inside one of the backend containers)
echo "Running database migration..."
BACKEND_CONTAINER=$(docker ps --filter "name=sia_backend" --format "{{.Names}}")
docker exec $BACKEND_CONTAINER npm run migrate

# Create a backup of the database
echo "Creating database backup..."
docker exec sia_master_mysql mysqldump -u sia_username -psia_password sia_db > ./database-backup.sql

# Create the initial user and tenant data
echo "Creating initial user and tenant data..."
docker exec $BACKEND_CONTAINER npm run create-initial-data

# Done, exit the script
echo "Setup completed. All containers are up and running."
exit 0
