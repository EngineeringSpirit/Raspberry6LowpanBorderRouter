#!/usr/bin/env bash

# check if root
if [ $UID -ne 0 ]; then
    echo "usage: sudo $0" &>2;
    exit;
fi;

export WORK_DIR="/root"
export CONFIGURE_SWITCHES="--prefix=/usr --sysconfdir=/etc --libdir=/usr/lib"

function check_bin() {
    while [ -n "$1" ]; do
	whereis -B `echo $PATH | sed "s/:/ /gi"` -f $1 | grep 'bin' > /dev/null || return 1
	shift;
    done

    return 0;
}

function check_grep() {
    grep -E "${1}" "${2}" > /dev/null 2> /dev/null && return 0 || return 1
}

function add_kernel_module() {
    if ! check_grep "^${1}\$" /etc/modules; then
	echo "[+] kernel: add module ${1} to auto loaded modules";
	echo "${1}" >> /etc/modules;
    else
	echo "[!] kernel: ${1} already loaded";
    fi;
}

function get_git() {
    if [ -d "${WORK_DIR}/$1" ]; then
	echo "[!] git: ${1} already downloaded";
    else
	echo "[+] git: downloading ${1} sources";
	git clone "${2}" "${1}"
    fi;
}

# fix the APT configuration
if ! [ -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
    echo "[+] apt: disable IPv6 support";
    echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4;
else
    echo "[!] apt: IPv6 already disabled";
fi;

# install system tools
if ! check_bin htop most strace; then
    echo "[+] installing system tools";
    apt-get -fy install htop most strace;
else
    echo "[!] system tools already installed";
fi;

# install compile support
if ! check_bin bc cmake git make automake pip; then
    echo "[+] installing compiler support tools";
    apt-get -fy install bc cmake git make dh-autoreconf automake libtool \
        bison flex build-essential linux-headers-rpi libnl-3-200 \
        libnl-cli-3-200 libnl-cli-3-dev python-zmq  libnl-3-dev \
        libnl-route-3-dev libnl-nf-3-dev cython libzmq-dev python-dev \
        python-pip libcap-dev;
else
    echo "[!] compiler support tools already installed";
fi;

# install network support
if ! check_bin nc6 dig bind9; then
    echo "[+] installing network support tools";
    apt-get -fy install netcat6 arptables bind9 dnsutils bind9utils tftpd-hpa;
else
    echo "[!] network tools already installed";
fi;

# check if the AT86RF233 overlay is loaded
if ! check_grep '^dtoverlay=at86rf233$' /boot/config.txt; then
    echo "[+] at86rf233: add device tree overlay";
    echo "dtoverlay=at86rf233" >> /boot/config.txt
else
    echo "[!] at86rf233: already configured";
fi;

# check if the required modules are loaded at startup
add_kernel_module configs
add_kernel_module 6lowpan

# check if the router configuration script is run at startup
if ! check_grep '^/root/6lowpan-router/setup_router.sh$' /etc/rc.local; then
    echo "[+] adding setup_router startup script";
    sed -i "/^exit 0\$/i /root/6lowpan-router/setup_router.sh" /etc/rc.local
else
    echo "[!] setup_router startup script already configured";
fi;

# check if the repositires are there
get_git radvd https://github.com/EngineeringSpirit/radvd.git;
get_git RplIcmp https://github.com/EngineeringSpirit/RplIcmp.git;
get_git Routing https://github.com/EngineeringSpirit/Routing.git;
get_git simpleRPL https://github.com/EngineeringSpirit/simpleRPL.git;
get_git wpan-tools https://github.com/EngineeringSpirit/wpan-tools.git;

# install radvd
if ! check_bin radvd; then
    echo "[+] building and installing radvd";
    cd radvd;
    ./autogen.sh
    ./configure ${CONFIGURE_SWITCHES}
    make install install-systemdsystemunitDATA
    systemctl enable radvd.service
    cp radvd.conf.example /etc/radvd.conf
    cd ..
else
    echo "[!] radvd already installed"
fi

# install wpan-tools
if ! check_bin iwpan; then
    echo "[+] building and installing wpan-tools";
    cd wpan-tools;
    ./autogen.sh
    ./configure ${CONFIGURE_SWITCHES}
    make install
    cd ..
else
    echo "[!] wpan-tools already installed"
fi

# install simpleRPL
if ! check_bin simpleRPL.py; then
    echo "[+] building and installing simpleRPL";
    cd RplIcmp && make; python setup.py install && cd ..;
    cd Routing && python setup.py install && cd ..;
    cd simpleRPL && python setup.py install && cd ..
else
    echo "[!] simpleRPL already installed"
fi

echo "[+] setup finished, reboot the system to finish the installation";
