FROM debian:stable-slim

RUN apt update && apt install -y iptables iptables-persistent isc-dhcp-server net-tools nano systemctl

COPY script-dhcp.sh /root/script-dhcp.sh
COPY script-firewall.sh /root/script-firewall.sh

RUN chmod +x /root/script-dhcp.sh /root/script-firewall.sh

CMD /root/script-firewall.sh && /root/script-dhcp.sh && tail -f /dev/null
