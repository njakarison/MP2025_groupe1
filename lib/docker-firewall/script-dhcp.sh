#!/bin/bash
echo 'DHCPDv4_CONF=/etc/dhcp/dhcpd.conf' > /etc/default/isc-dhcp-server
echo 'INTERFACESv4="enp0s3"' >> /etc/default/isc-dhcp-server

cat <<EOL > /etc/dhcp/dhcpd.conf
option domain-name "gerioux.com";
default-lease-time 345600;
max-lease-time 691200;
authoritative;
log-facility local7;

subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.10 192.168.1.20;
    option domain-name-servers 8.8.8.8;
    option routers 192.168.1.1;
}
EOL

systemctl restart isc-dhcp-server.service
