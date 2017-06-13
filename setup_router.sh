#!/usr/bin/env sh

echo "[+] restarting radvd"
systemctl stop radvd
echo "[+] enable IPv6 support"
modprobe ipv6
echo "[+] bringing down links"
ip link set wpan0 down
ip link set lowpan0 down
echo "[+] remove the old PAN network device"
iwpan dev wpan0 del
iwpan phy phy0 interface add wpan0 type node 00:00:00:00:00:00:00:01
echo "[+] configure the module for O-QPSK at for 868 Mhz"
iwpan phy phy0 set channel 2 0
echo "[+] configure the module for full TX power"
iwpan phy phy0 set tx_power 11
echo "[+] add a new link for IPv6"
ip link add link wpan0 name lowpan0 type lowpan
echo "[+] setting network ID to: 0x23"
iwpan dev wpan0 set pan_id 0x23
echo "[+] bringing up links"
ip link set wpan0 up
ip link set lowpan0 up
echo "[+] enable forwarding"
sysctl -w net.ipv6.conf.all.forwarding=1
echo "[+] adding IPv6 addresses"
ip address add fdcb:62::1/64 dev eth0
ip address add fdcb:61::1/64 dev lowpan0
ip address add fdcb:66::1/64 dev lowpan0
echo "[+] disable UDP header compression"
#rmmod nhc_udp
echo "[+] change the IPv4 address of the Raspberry PI"
ifconfig eth0 172.31.0.100 netmask 255.255.254.0
echo "[+] start router advertisements"
systemctl start radvd
echo "[+] start RPL DODAG root"
simpleRPL.py -i lowpan0 -d fdcb:66::1 -R -p fdcb:66:: &
echo "!! ready for 6LoWPAN routing !!"
