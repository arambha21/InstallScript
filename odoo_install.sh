#!/bin/bash
################################################################################
# Script for installing Odoo 18 Enterprise on Ubuntu 22.04 and above
# Author: Atul Makwana, Heliconia Solutions Pvt. Ltd. (https://www.linkedin.com/in/atulmakwana/)
# Adapted from Yenthe Van Ginneken's script
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Odoo 18 version (master branch as 18.0 is not yet released)
OE_VERSION="15.0"
# Set this to True for enterprise version
IS_ENTERPRISE="True"
# Install PostgreSQL 16
INSTALL_POSTGRESQL_SIXTEEN="True"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="True"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Set the website name
WEBSITE_NAME="_"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="False"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install libpq-dev -y

#--------------------------------------------------
# Install PostgreSQL 16
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL 16 Server ----"
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install postgresql-16 -y
    systemctl start postgresql
fi

echo -e "\n---- Creating the ODOO PostgreSQL User ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Python 3.12
#--------------------------------------------------
echo -e "\n---- Install Python 3.12 ----"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install python3.12 python3.12-dev python3.12-venv -y
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
sudo apt-get install git wget python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y


echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\n---- Install wkhtmltopdf ----"
    sudo apt-get install wkhtmltopdf -y
fi

#--------------------------------------------------
# Create System User
#--------------------------------------------------
echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER


echo -e "\n---- Install python packages/requirements ----"
# Create a virtual environment for Odoo
python3.12 -m venv $OE_HOME/venv
source $OE_HOME/venv/bin/activate
pip3 install wheel
pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt


#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

    pip3 install psycopg2-binary pdfminer.six
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/arambha21/enterprise "$OE_HOME/enterprise/addons" 2>&1

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    source $OE_HOME/venv/bin/activate
    pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL python-stdnum==1.20 phonenumbers
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

#--------------------------------------------------
# Configure Odoo
#--------------------------------------------------
echo -e "* Create server config file"
sudo touch /etc/${OE_CONFIG}.conf
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Create Systemd unit file
#--------------------------------------------------
echo -e "* Create systemd unit file"
cat <<EOF > /lib/systemd/system/${OE_CONFIG}.service
[Unit]
Description=Odoo Open Source ERP and CRM
After=network.target postgresql.service

[Service]
Type=simple
User=$OE_USER
Group=$OE_USER
ExecStart=$OE_HOME/venv/bin/python3 $OE_HOME_EXT/odoo-bin --config /etc/${OE_CONFIG}.conf
KillMode=mixed
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Starting Odoo Service"
sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}
sudo systemctl start ${OE_CONFIG}

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "Python version: 3.12"
echo "PostgreSQL version: 16"
echo "Configuration file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Start Odoo service: sudo systemctl start $OE_CONFIG"
echo "Stop Odoo service: sudo systemctl stop $OE_CONFIG"
echo "Restart Odoo service: sudo systemctl restart $OE_CONFIG"
echo "-----------------------------------------------------------"
