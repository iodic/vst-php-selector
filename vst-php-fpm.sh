#!/bin/bash
set -e

# check root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# check OS
if [[ `cat /etc/os-release | grep ^ID=` == "ID=debian" ]]; then
    apt install -y apt-transport-https lsb-release ca-certificates wget
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
    apt update
elif [[ `cat /etc/os-release | grep ^ID=` == "ID=ubuntu" ]]; then
    apt update
    add-apt-repository ppa:ondrej/php
else    
    echo "This script must be run on Ubuntu or Debian"
    exit 1
fi

a2enmod proxy_fcgi setenvif

echo "You can enter multiple versions through 'space'."
echo "Enter php version/versions(for example 5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2, 8.3):"
read -p ">" vers

# validate input
if [[ -z "$vers" ]]; then
    echo "Error: No PHP versions specified"
    exit 1
fi

site_link="https://raw.githubusercontent.com/iodic/vst-php-selector/main/fpm"

for ver in $vers; do

    echo "Installing PHP $ver..."
    
    if ! apt install -y php$ver php$ver-fpm php$ver-cgi; then
        echo "Error: Failed to install PHP $ver"
        continue
    fi

    a2enconf php$ver-fpm

    # Create backup directory
    BACKUP_DIR="/home/admin/vst_install_backups/php$ver"
    if ! [ -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Backup existing config
    if [ -d /etc/php/$ver/ ]; then
        cp -r /etc/php/$ver/ "$BACKUP_DIR/"
        rm -f /etc/php/$ver/fpm/pool.d/*
    fi

    # Download templates with verification
    TEMPLATE_DIR="/usr/local/vesta/data/templates/web/apache2"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo "Error: Vesta template directory not found: $TEMPLATE_DIR"
        continue
    fi
    
    for file in php-fpm-$ver.stpl php-fpm-$ver.tpl php-fpm-$ver.sh; do
        if wget -q "$site_link/$file" -O "$TEMPLATE_DIR/$file"; then
            echo "Downloaded $file"
        else
            echo "Error: Failed to download $file"
            continue 2
        fi
    done
    
    chmod a+x "$TEMPLATE_DIR/php-fpm-$ver.sh"
    echo "PHP $ver installation completed"

done

systemctl restart apache2
