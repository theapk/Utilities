#!/bin/bash

# Define color
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting the MongoDB installation process...${NC}"

echo -e "${YELLOW}Updating the packages list...${NC}"
sudo apt-get update

echo -e "${YELLOW}Ubuntu 22.04 has upgraded libssl to 3 and does not propose libssl1.1.${NC}"
echo -e "${YELLOW}Adding the Ubuntu 20.04 source to install libssl1.1...${NC}"
echo "deb http://security.ubuntu.com/ubuntu focal-security main" | sudo tee /etc/apt/sources.list.d/focal-security.list

echo -e "${YELLOW}Updating the packages list again...${NC}"
sudo apt-get update

echo -e "${YELLOW}Installing libssl1.1...${NC}"
sudo apt-get install libssl1.1

echo -e "${YELLOW}Importing the MongoDB public GPG Key...${NC}"
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

echo -e "${YELLOW}Creating a list file for MongoDB...${NC}"
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

echo -e "${YELLOW}Reloading local package database...${NC}"
sudo apt-get update

echo -e "${YELLOW}Installing MongoDB...${NC}"
sudo apt-get install -y mongodb-org

echo -e "${YELLOW}Starting MongoDB...${NC}"
sudo systemctl start mongod

echo -e "${YELLOW}Enabling MongoDB to start on reboot...${NC}"
sudo systemctl enable mongod

echo -e "${YELLOW}Verifying the installation...${NC}"
if [ "$(systemctl is-active mongod)" = "active" ]
then
    echo -e "${YELLOW}MongoDB service is active.${NC}"
else
    echo -e "${YELLOW}MongoDB service is not active. Check your installation.${NC}"
fi

echo -e "${YELLOW}Cleaning up - removing the focal-security list file...${NC}"
sudo rm /etc/apt/sources.list.d/focal-security.list

echo -e "${YELLOW}MongoDB installation process completed.${NC}"
