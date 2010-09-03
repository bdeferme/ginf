#!/bin/bash
#
# gINF (gather Information)
# is a script written by: Bert Deferme <bert@bdeferme.net>
#
# Description:
# Gather as much system information as possible, and store it in a config dir
# for future reference.
#
# Released as GPLv3
#

VERSION=0.2.0

MAKETAR=0
OUT=/dev/null

showUsage() {
	echo "Usage: $0"
	echo "  -h	: show this help"
	echo "  -v	: be verbose"
	echo "  -t	: make tar"
	exit 0
}

while getopts "tvh" Option
do
	case $Option in
		t) MAKETAR=1
		;;
		v) OUT=/dev/stdout
		;;
		h) showUsage
		;;
		*) showUsage
		;;
	esac
done

echo > $OUT
echo "You are running gINF v${VERSION}" > $OUT

#
# Check if root!
#

MYID=$(whoami)

if [ ! "$MYID" == "root" ];
then
  echo "ERR: Please run as root"
  exit 1
fi

#
# OUTPUT VARS / CATEGORIES
#

echo "Creating directory $OUTPUT_DIR"

OUTPUT_DIR="$(pwd)/$(hostname)-config";
EXISTS=0  
[[ -d $OUTPUT_DIR ]] && echo "$OUTPUT_DIR exists!" && EXISTS=1

if [[ $EXISTS == "1" ]]; then
  while [[ ! ( $ANSA == "y" || $ANSA == "n" ) ]]; do
  echo
  echo "Overwrite (y/n)? "
  read -n 1 ANSA
  done

  [[ $ANSA == "y" ]] && rm -rf $OUTPUT_DIR && mkdir $OUTPUT_DIR && echo ""
  [[ $ANSA == "n" ]] && echo "Not creating $OUTPUT_DIR" && echo "Exiting." && exit
else
  mkdir $OUTPUT_DIR
fi 

NWDIR="${OUTPUT_DIR}/network"; mkdir $NWDIR
GENDIR="${OUTPUT_DIR}/general"; mkdir $GENDIR
PROCDIR="${OUTPUT_DIR}/proc"; mkdir $PROCDIR
RESDIR="${OUTPUT_DIR}/resources"; mkdir $RESDIR
DDIR="${OUTPUT_DIR}/disk"; mkdir $DDIR

#
# Distribution Discovery
#

OS=$(uname -s)

if [ $OS = "SunOS" ];
  then 
  OS=Solaris
elif [ $OS = "Linux" ];
  then
  if [ -f /etc/redhat-release ];
    then
    DIST="Redhat"
    REV=$(cat /etc/redhat-release)
  elif [ -f /etc/debian_version ];
    then
    DIST="Debian"
    REV=$(cat /etc/debian_version)
  fi
fi

echo 
echo "Running on $OS $DIST $REV"
echo

#
# Test for needed tools
#
TOOLS="ifconfig route iptables netstat df mount vgdisplay fdisk lspci lsusb lsmod free lsb_release ps getent ntpq dmesg uptime uname"

#
# Distribution specific tools
#
echo "Gathering repository information"
if [[ $DIST == "Redhat" ]];
then
  TOOLS="${TOOLS} chkconfig yum"
elif [[ $DIST == "Debian" ]];
then
  TOOLS="${TOOLS} dpkg blkid"
fi

NOTOOLS=""

for tool in $TOOLS; do
  TOOLP=$(which $tool 2> /dev/null)
  if [[ x$TOOLP = "x" ]]; then
    NOTOOLS="${NOTOOLS}$tool "
  fi
done

if [[ ! x$NOTOOLS = "x" ]]; then
  echo "ERR: The following needed tools are not installed:"
  echo $NOTOOLS
  echo
  while [[ ! ( $ANSB == "y" || $ANSB == "n" ) ]]; do
  echo
  echo "Continue anyway (y/n)? "
  read -n 1 ANSB
  done

  [[ $ANSB == "n" ]] && echo "Exiting." && exit
fi

echo ""

#
# PROC Information
#

echo "Gathering /proc/ information..."
GOTPROC=""

function getProc {
cat /proc/$1 > ${PROCDIR}/$1
GOTPROC="${GOTPROC} $1"
}

getProc cpuinfo
getProc meminfo
getProc modules
getProc partitions
getProc devices
getProc interrupts
getProc loadavg

echo "  * got /proc/ information for: ${GOTPROC}." > $OUT

#
# Network information
#

echo "Gathering network information"
echo "  * ifconfig -a" > $OUT
ifconfig -a > ${NWDIR}/ifconfig-a

echo "  * route -n" > $OUT
route -n > ${NWDIR}/route-n
echo "  * resolv.conf" > $OUT
cp /etc/resolv.conf ${NWDIR}/resolv.conf

# firewall
echo "  * firewall" > $OUT
echo "Gathering firewall rules" > $OUT
echo "iptables -L -n -v" > ${NWDIR}/iptables
echo "" >> ${NWDIR}/iptables

IPT=`which iptables 2> /dev/null`

if [ ! x$IPT = x ]; then
	iptables -L -n -v >> ${NWDIR}/iptables
fi
echo "" >> ${NWDIR}/iptables
echo "iptables -L -n -t nat -v" >> ${NWDIR}/iptables
echo "">> ${OUTPUT_DIR}/iptables
if [ ! x$IPT = x ]; then
	iptables -L -n -t nat -v >> ${NWDIR}/iptables
fi
echo "  * netstat" > $OUT
netstat -anp > ${NWDIR}/netstat-anp

# config
echo "  * config" > $OUT
if [[ $DIST = "Redhat" ]];
then
  > ${NWDIR}/network_config
  for i in /etc/sysconfig/network-scripts/ifcfg-*; do echo $i >> ${NWDIR}/network_config && cat $i >> ${NWDIR}/network_config; done
elif [[ $DIST = "Debian" ]];
then
  cp /etc/network/interfaces ${NWDIR}/network_config
else
  echo "    ! sorry, your distribution $OS $DIST ($REV) is unsupported"
fi

echo "  * hostname" > $OUT
hostname > ${NWDIR}/hostname

echo "  * /etc/hosts" > $OUT
cp /etc/hosts ${NWDIR}/hosts

echo "  * sshd_config" > $OUT
cp /etc/ssh/sshd_config ${NWDIR}/sshd_config

#
# Disk information
#

echo "Gathering disk information..."

echo "  * df -h" > $OUT
df -h > ${DDIR}/df-h

echo "  * /etc/fstab" > $OUT
cp /etc/fstab ${DDIR}/fstab

echo "  * mount" > $OUT
mount > ${DDIR}/mount

echo "  * lvm" > $OUT
vgdisplay -vv > ${DDIR}/vgdisplay-vv 2> /dev/null

echo "  * fdisk -l" > $OUT
fdisk -l 2> /dev/null > ${DDIR}/fdisk-l

#
# Resource information
# 

echo "Gathering resource information..."

echo "  * lspci" > $OUT
lspci > ${RESDIR}/lspci

echo "  * lsusb" > $OUT
lsusb > ${RESDIR}/lsusb

echo "  * free -m" > $OUT
free -m > ${RESDIR}/free-m

echo "  * lsmod" > $OUT
lsmod > ${RESDIR}/lsmod

echo "  * running processes" > $OUT
ps aux | sort -u > ${RESDIR}/running_processes

#
# General information
#

echo "Gathering general information..."

echo "  * distribution information" > $OUT
echo "Running on $OS $DIST $REV" > ${GENDIR}/os_information
lsb_release -a > ${GENDIR}/lsb_release-a

function doGetEnt {
getent $1 > ${GENDIR}/$1
GOTENT="${GOTENT} $1"
}

doGetEnt passwd
doGetEnt group
doGetEnt shadow

echo "  * getent for: $GOTENT" > $OUT

echo "  * sudoers" > $OUT
cp /etc/sudoers ${GENDIR}/sudoers

echo "  * crontabs" > $OUT
mkdir ${GENDIR}/crontabs
for i in $( ls /var/spool/cron/crontabs ); do
  cp -rf /var/spool/cron/crontabs/${i} ${GENDIR}/crontabs/${i}
done

echo "  * ntpq -p" > $OUT
ntpq -p > ${GENDIR}/ntpq-p

echo "  * /etc/motd" > $OUT
cp /etc/motd ${GENDIR}/motd

echo "  * /etc/sysctl" > $OUT
cp /etc/sysctl.conf ${GENDIR}/sysctl.conf

echo "  * dmesg" > $OUT
dmesg > ${GENDIR}/dmesg

echo "  * uptime" > $OUT
uptime > ${GENDIR}/uptime

echo "  * uname -a" > $OUT
uname -a > ${OUTPUT_DIR}/uname-a

#
# Distribution Dependant Information
#

echo "Gathering Enabled Services"
if [[ $DIST = "Redhat" ]];
then
  chkconfig --list > ${OUTPUT_DIR}/chkconfig--list
elif [[ $DIST = "Debian" ]];
then
  > ${OUTPUT_DIR}/enabled_services
  R=$(runlevel  | awk '{ print $2}')
  for s in /etc/rc${R}.d/*; do  basename $s | grep '^S' | sed 's/S[0-9].//g' >> ${OUTPUT_DIR}/enabled_services ;done
else
  echo "ERR: Sorry, your distribution $OS $DIST ($REV) is unsupported"
fi

echo "Gathering installed packages"
if [[ $DIST = "Redhat" ]];
then
  yum list > ${OUTPUT_DIR}/installed_packages
elif [[ $DIST = "Debian" ]];
then
  dpkg -l > ${OUTPUT_DIR}/installed_packages
else
  echo "ERR: Sorry, your distribution $OS $DIST ($REV) is unsupported"
fi

if [[ $DIST = "Debian" ]];
then
  BLKID=$(which blkid 2> /dev/null)
  if [ ! x"$BLKID" == "x" ];
  then
    blkid > ${OUTPUT_DIR}/blkid
  fi
fi

echo "Gathering repository information"
if [[ $DIST = "Redhat" ]];
then
  cp -rf /etc/yum.repos.d/ ${OUTPUT_DIR}/
elif [[ $DIST = "Debian" ]];
then
  cp -rf /etc/apt/*sources* ${OUTPUT_DIR}/ 
else
  echo "ERR: Sorry, your distribution $OS $DIST ($REV) is unsupported"
fi

if [[ $MAKETAR == "1" ]];
then
  tar cf ${OUTPUT_DIR}.tar ${OUTPUT_DIR}
  rm -rf ${OUTPUT_DIR}
fi
