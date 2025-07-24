#!/bin/bash
# Script to generate secrets for GitHub Actions workflow

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating secrets for GitHub Actions workflow...${NC}\n"

# Generate SECRET_KEY_BASE
echo -e "${YELLOW}Generating SECRET_KEY_BASE...${NC}"
SECRET_KEY_BASE=$(mix phx.gen.secret)
echo -e "SECRET_KEY_BASE: ${GREEN}$SECRET_KEY_BASE${NC}\n"

# Instructions for DATABASE_URL
echo -e "${YELLOW}For DATABASE_URL, use the following format:${NC}"
echo -e "ecto://USER:PASS@HOST/DATABASE\n"

# Instructions for PHX_HOST
echo -e "${YELLOW}For PHX_HOST, use your production domain:${NC}"
echo -e "example.com\n"

# Instructions for SSH deployment
echo -e "${YELLOW}For deployment via SSH, you'll need:${NC}"
echo -e "1. SSH_PRIVATE_KEY: Your private SSH key (cat ~/.ssh/id_rsa)"
echo -e "2. SSH_HOST: Your server hostname"
echo -e "3. SSH_USER: Your server username\n"

echo -e "${GREEN}Add these secrets to your GitHub repository:${NC}"
echo -e "1. Go to your GitHub repository"
echo -e "2. Click on 'Settings'"
echo -e "3. Click on 'Secrets and variables' -> 'Actions'"
echo -e "4. Click on 'New repository secret'"
echo -e "5. Add each secret with its corresponding value\n"

echo -e "${GREEN}Done!${NC}"