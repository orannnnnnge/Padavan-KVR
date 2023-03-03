#!/bin/sh

change_dns() {
	if [ "$(nvram get adg_redirect)" = 1 ]; then
		sed -i '/no-resolv/d' /etc/storage/dnsmasq/dnsmasq.conf
		sed -i '/server=127.0.0.1/d' /etc/storage/dnsmasq/dnsmasq.conf
		echo "no-resolv" >> /etc/storage/dnsmasq/dnsmasq.conf
		echo "server=127.0.0.1#5335" >> /etc/storage/dnsmasq/dnsmasq.conf
		/sbin/restart_dhcpd
		logger -t "AdGuardHome" "添加DNS转发到5335端口"
	fi
}

set_iptable() {
	if [ "$(nvram get adg_redirect)" = 2 ]; then
		IPS="`ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}'`"
		for IP in $IPS
		do
			iptables -t nat -A PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
			iptables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
		done
		IPS="`ifconfig | grep "inet6 addr" | grep -v " fe80::" | grep -v " ::1" | grep "Global" | awk '{print $3}'`"
		for IP in $IPS
		do
			ip6tables -t nat -A PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
			ip6tables -t nat -A PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
		done
		logger -t "AdGuardHome" "重定向53端口"
	fi
}

del_dns() {
	sed -i '/no-resolv/d' /etc/storage/dnsmasq/dnsmasq.conf
	sed -i '/server=127.0.0.1#5335/d' /etc/storage/dnsmasq/dnsmasq.conf
	/sbin/restart_dhcpd
}

clear_iptable() {
	IPS="`ifconfig | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}'`"
	for IP in $IPS
	do
		iptables -t nat -D PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
		iptables -t nat -D PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
	done
	IPS="`ifconfig | grep "inet6 addr" | grep -v " fe80::" | grep -v " ::1" | grep "Global" | awk '{print $3}'`"
	for IP in $IPS
	do
		ip6tables -t nat -D PREROUTING -p tcp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
		ip6tables -t nat -D PREROUTING -p udp -d $IP --dport 53 -j REDIRECT --to-ports 5335 >/dev/null 2>&1
	done
}

start_adg() {
	mkdir -p /etc/storage/AdGuardHome
	change_dns
	set_iptable
	eval "/usr/bin/AdGuardHome -w /etc/storage/AdGuardHome -v" &
	logger -t "AdGuardHome" "运行AdGuardHome"
}

stop_adg() {
	killall -9 AdGuardHome
	del_dns
	clear_iptable
}

case $1 in
	start)
	start_adg
	;;
	stop)
	stop_adg
	;;
	*)
	echo "check"
	;;
esac
