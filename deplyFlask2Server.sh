#!/bin/bash

# Define color
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define variables
MYPROJECT=$1
MYPROJECTUSER=$2
MYDOMAIN=$3
MYPROJECTENV=$4

# Check if all arguments are provided
if [ -z "$MYPROJECT" ] || [ -z "$MYPROJECTUSER" ] || [ -z "$MYDOMAIN" ] || [ -z "$MYPROJECTENV" ]
then
    echo "Usage: $0 myproject myprojectuser mydomain myprojectenv"
    exit 1
fi

echo_section_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

check_command_status() {
    if [ $1 -ne 0 ]; then
        echo -e "${YELLOW}ERROR: $2${NC}"
        exit 1
    fi
}

check_section_completed() {
    if [ -f "$1" ]; then
        echo -e "${YELLOW}*** $2 has already been completed. Skipping... ***${NC}"
        return 0
    fi
    return 1
}

echo_section_header "Updating package lists"
sudo apt update || true
check_section_completed "/var/lib/apt/lists/lock" "Updating package lists"
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}Skipping package list update as it has already been completed.${NC}"
fi

echo_section_header "Installing Python3 pip"
sudo apt install -y python3-pip
check_command_status $? "Failed to install Python3 pip"

echo_section_header "Installing venv"
sudo apt install -y python3-venv
check_command_status $? "Failed to install venv"

echo_section_header "Creating a new virtual environment"
check_section_completed "$MYPROJECTENV/bin/activate" "Creating virtual environment"
if [ $? -ne 0 ]; then
    python3 -m venv $MYPROJECTENV
    check_command_status $? "Failed to create virtual environment"
fi

echo_section_header "Activating the virtual environment"
source $MYPROJECTENV/bin/activate
check_command_status $? "Failed to activate virtual environment"

echo_section_header "Upgrading pip"
pip install --upgrade pip
check_command_status $? "Failed to upgrade pip"

echo_section_header "Installing Flask"
pip install Flask
check_command_status $? "Failed to install Flask"

echo_section_header "Installing gunicorn"
pip install gunicorn
check_command_status $? "Failed to install gunicorn"

echo_section_header "Creating a new system user for our project"
if id -u $MYPROJECTUSER >/dev/null 2>&1; then
    echo -e "${YELLOW}*** System user '$MYPROJECTUSER' already exists. Skipping user creation. ***${NC}"
else
    sudo useradd -m -d /home/$MYPROJECTUSER -s /bin/bash $MYPROJECTUSER
    check_command_status $? "Failed to create system user"
fi

echo_section_header "Changing the ownership of our project directory to the new user"
check_section_completed "/home/$MYPROJECTUSER/$MYPROJECT" "Changing ownership"
if [ $? -ne 0 ]; then
    sudo chown -R $MYPROJECTUSER:$MYPROJECTUSER /home/$MYPROJECTUSER/$MYPROJECT
    check_command_status $? "Failed to change ownership"
fi

echo_section_header "Creating the 'sites-available' directory for Nginx"
check_section_completed "/etc/nginx/sites-available" "Creating 'sites-available' directory"
if [ $? -ne 0 ]; then
    sudo mkdir -p /etc/nginx/sites-available
    check_command_status $? "Failed to create 'sites-available' directory"
fi

echo_section_header "Creating the 'sites-enabled' directory for Nginx"
check_section_completed "/etc/nginx/sites-enabled" "Creating 'sites-enabled' directory"
if [ $? -ne 0 ]; then
    sudo mkdir -p /etc/nginx/sites-enabled
    check_command_status $? "Failed to create 'sites-enabled' directory"
fi

echo_section_header "Configuring Nginx"
check_section_completed "/etc/nginx/sites-available/$MYPROJECT" "Configuring Nginx"
if [ $? -ne 0 ]; then
    sudo tee /etc/nginx/sites-available/$MYPROJECT > /dev/null << EOF
server {
    listen 80;
    server_name $MYDOMAIN;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    check_command_status $? "Failed to configure Nginx"
fi

echo_section_header "Enabling the Nginx server block"
check_section_completed "/etc/nginx/sites-enabled/$MYPROJECT" "Enabling Nginx server block"
if [ $? -ne 0 ]; then
    sudo ln -s /etc/nginx/sites-available/$MYPROJECT /etc/nginx/sites-enabled/$MYPROJECT
    check_command_status $? "Failed to enable Nginx server block"
fi

echo_section_header "Testing Nginx configuration"
sudo nginx -t
check_command_status $? "Failed to test Nginx configuration"

echo_section_header "Restarting the Nginx service"
sudo systemctl restart nginx
check_command_status $? "Failed to restart Nginx service"

echo_section_header "Adding firewall rules for HTTP and HTTPS"
sudo ufw allow http
check_command_status $? "Failed to add firewall rule for HTTP"
sudo ufw allow https
check_command_status $? "Failed to add firewall rule for HTTPS"

echo_section_header "Installing certbot"
sudo apt install -y certbot python3-certbot-nginx
check_command_status $? "Failed to install certbot"

echo_section_header "Requesting Let's Encrypt SSL certificate"
sudo certbot --nginx -d $MYDOMAIN --non-interactive --agree-tos --email admin@$MYDOMAIN
check_command_status $? "Failed to request SSL certificate"

echo_section_header "Setting up automatic certificate renewal"
sudo crontab -l | { cat; echo "0 0 * * * certbot renew --quiet"; } | sudo crontab -
check_command_status $? "Failed to set up automatic certificate renewal"

echo_section_header "Starting the Gunicorn server"
sudo -u $MYPROJECTUSER $MYPROJECTENV/bin/gunicorn --bind 0.0.0.0:80 --chdir /home/CCUser/CronCron app:app &
check_command_status $? "Failed to start Gunicorn server"

sleep 2  # Wait for Gunicorn to start

echo_section_header "Checking if the Flask app is running"
if pgrep -f "gunicorn.*$MYPROJECT"; then
    echo -e "${YELLOW}The Flask app is running.${NC}"
else
    echo -e "${YELLOW}The Flask app is not running. Please check your deployment.${NC}"
fi

echo_section_header "Flask app deployment completed"
