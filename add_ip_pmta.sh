#!/bin/bash

echo "please create custom NS record 'ns1' value 'your_server_ip"
echo "please create custom NS record 'ns2' value 'your_server_ip"

echo "Do you want to continue running the script? (yes/no)"
read response

# Check the user's response
if [ "$response" = "yes" ]; then
    echo "Continuing the script..."
    # Add your script logic here
else
    echo "Exiting the script."
    exit 0
fi

echo "please cancel this run and check your network name is eth0 or ens33"

echo "If you know network name continue running the script? (yes/no)"
read response

# Check the user's response
if [ "$response" = "yes" ]; then
    read -p "Enter network name " network
     
    echo "Continuing the script..."
    # Add your script logic here
else
    echo "Exiting the script."
    exit 0
fi

yum update -y

read -p "Enter website domain: " domain
host="ns1"
read -p "Enter your ip: " serverip
read -p "Enter your username for PMTA: " pmtauser
read -sp "Enter your password for PMTA: " pmtapass

###set hostname
hostnamectl set-hostname $host.$domain

#install pmta
yum install wget perl vim -y
wget -O install.sh https://www.dropbox.com/s/d7kfwr2zzakrs47/installpmta5r7.sh
chmod +x install.sh
./install.sh

#delete old config and download new config
rm -rf /etc/pmta/config

#install new config file
wget https://www.dropbox.com/s/f46jmke71r6jziu/config
source_path="/root/config"
destination_path="/etc/pmta/config"

# Check if the source file exists
if [ -f "$source_path" ]; then
    # Move the file to the destination
    mv "$source_path" "$destination_path"
    echo "File moved successfully!"
else
    echo "Source file does not exist."
fi

#creating pem file and moving
openssl genrsa -out dkim.private.key 1024
openssl rsa -in dkim.private.key -out dkim.public.key -pubout -outform PEM
mv dkim.private.key dkim.pem

source_path="/root/dkim.pem"
destination_path="/etc/pmta/dkim.pem"

# Check if the source file exists
if [ -f "$source_path" ]; then
    # Move the file to the destination
    mv "$source_path" "$destination_path"
    echo "File moved successfully!"
else
    echo "Source file does not exist."
fi

config_file="/etc/pmta/config"

sed -i '92 d' /etc/pmta/config
sed -i '91 d' /etc/pmta/config
sed -i '90 d' /etc/pmta/config
sed -i '89 d' /etc/pmta/config
sed -i '88 d' /etc/pmta/config

sed -i "s/postmaster admin@domain.com/postmaster admin@$domain/" "$config_file"
sed -i "s/smtp-listener server_ip:2525/smtp-listener $serverip:2525/" "$config_file"
sed -i "s/<smtp-user pmtauser>/<smtp-user $pmtauser>/" "$config_file"
sed -i "s/password pmtapass/password $pmtapass/" "$config_file"
sed -i "s/smtp-source-host server_ip hostname/smtp-source-host $serverip $host.$domain/" "$config_file"
sed -i "s/domain12/$domain/" "$config_file"
sed -i "s/<domain domain.com>/<domain $domain>/" "$config_file"

old_string="domain-key default,*,/etc/opendkim/keys/swgsv.com/default.private"
new_string="domain-key default,*,/etc/pmta/dkim.pem"
sed -i "s|$old_string|$new_string|g" "/etc/pmta/config"


########## adding additional ip
i=1

while true; do

    read -p "Enter additional ip (or 'exit' to quit): " input

    if [[ $input == "exit" ]]; then
        echo "Exiting..."
        break
    fi
    
    ip addr add $input dev $network:i

    config_file="/etc/sysconfig/network-scripts/ifcfg-$network:$i"
    echo "DEVICE=\"$network:$i\"" > "$config_file"
    echo "ONBOOT=\"yes\"" >> "$config_file"
    echo "BOOTPROTO=\"static\"" >> "$config_file"
    echo "IPADDR=\"$input\"" >> "$config_file"
    echo "NETMASK=\"255.255.255.255\"" >> "$config_file"
    echo "BROADCAST=\"$input\"" >> "$config_file"

    echo "<virtual-mta pmta-vmta$i>" >> /etc/pmta/config
    echo "smtp-source-host $input $host$i.$domain" >> /etc/pmta/config
    echo "</virtual-mta>" >> /etc/pmta/config

    i=$((i+1))
done

echo "<virtual-mta-pool pmta-pool>" >> /etc/pmta/config

for (( j=0; j<=i; j++ )); do
    echo "virtual-mta pmta-vmta$j" >> /etc/pmta/config
done

echo "</virtual-mta-pool>" >> /etc/pmta/config

systemctl restart NetworkManager

sed -i '3 d' /etc/resolv.conf
sed -i '4 d' /etc/resolv.conf
echo "nameserver	8.8.8.8" >> /etc/resolv.conf
echo "domain-key default,*,/etc/pmta/dkim.pem" >> /etc/pmta/config

service pmta start
service pmtahttp restart