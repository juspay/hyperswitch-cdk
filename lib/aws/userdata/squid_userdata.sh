#!/bin/bash

# Setup Wazuh
aws s3 cp s3://{{bucket-name}}/wazuh.conf /var/ossec/etc/ossec.conf
chown root:ossec /var/ossec/etc/ossec.conf
systemctl restart wazuh-agent

# Setup Vector
rm /etc/vector/vector.toml
aws s3 cp s3://{{bucket-name}}/squid_vector.toml /etc/vector/vector.toml
chown vector:vector /etc/vector/vector.toml
systemctl restart vector

# update squid conf
cp /etc/squid/squid.conf /etc/squid/squid.conf.old
aws s3 cp s3://{{bucket-name}}/squid.conf /etc/squid/squid.conf

# Refresh squid
echo 'aws s3 cp s3://{{bucket-name}}/whitelist.txt /etc/squid/tmp_whitelist.txt
upstreamVersion=$(md5sum /etc/squid/tmp_whitelist.txt | awk {'\'print \$1\''})
hostVersion=$(md5sum /etc/squid/squid.allowed.sites.txt| awk {'\'print \$1\''})
if [ $upstreamVersion != $hostVersion ]
then
  cp /etc/squid/squid.allowed.sites.txt /etc/squid/squid.allowed.sites.txt.old
  cp /etc/squid/tmp_whitelist.txt /etc/squid/squid.allowed.sites.txt
  /usr/sbin/squid/squid -k reconfigure
  echo "`date "+%Y-%m-%d %H-%M-%S %Z"` Squid config updated"
else
  echo "`date "+%Y-%m-%d %H-%M-%S %Z"` No change"
fi'> /etc/squid/update_whitelist.sh

# Create squid coredump dir
mkdir -p /var/spool/squid

chmod +x /etc/squid/update_whitelist.sh
bash /etc/squid/update_whitelist.sh
echo "*/15 * * * * root /etc/squid/update_whitelist.sh" >> /etc/crontab

ufw allow out 3100/tcp