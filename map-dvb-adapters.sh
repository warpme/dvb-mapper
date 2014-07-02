#!/bin/sh

# This script allows symlinking DVB adapters to constant & user defined
# symlinks. It is usable when kernel assigns different DVB adapter number on
# every boot. Script requires:
#   1.udev rule which saves boot time adapter number assigned by kernel
#   2.conf file which defines symlinks of persistent adapter numbers
#
# Format of udev rule is following:
#SUBSYSTEM=="dvb", KERNEL=="dvb[0-9].frontend0", \
#	    \
#	    ATTRS{subsystem_vendor}=="<vendor_id>",	\
#	    ATTRS{subsystem_device}=="<vendor_id>",	\
#	    \
#	    , PROGRAM="/bin/sh -c 'rc=`grep -c -s %k /tmp/dvb-adapter-%k.map`; if [ $rc != 0 ] ; then exit 0 ; else echo \
#	    \
#	    <card_name>:%k \
#	    \
#	    >> /tmp/dvb-adapter-%k.map; fi ; exit 0'"
#
# Format of conf file is following:
#    <card_name>:<symlink_number>
#
# Example:
# For 2 cards like dual DVBS S480 & quad DVBS TBS9841
# udev rule will be following:
#SUBSYSTEM=="dvb", KERNEL=="dvb[0-9].frontend0", \
#	    \
#	    ATTRS{subsystem_vendor}=="0xa000", \
#	    ATTRS{subsystem_device}=="0x4000", \
#	    \
#	    , PROGRAM="/bin/sh -c 'rc=`grep -c -s %k /tmp/dvb-adapter-%k.map`; if [ $rc != 0 ] ; then exit 0 ; else echo \
#	    \
#	    Tevii_S480:%k \
#	    \
#	    >> /tmp/dvb-adapter-%k.map; fi ; exit 0'"
#
#SUBSYSTEM=="dvb", KERNEL=="dvb[0-9].frontend0", \
#	    \
#	    ATTRS{subsystem_vendor}=="t.b.i", \
#	    ATTRS{subsystem_device}=="t.b.i", \
#	    \
#	    , PROGRAM="/bin/sh -c 'rc=`grep -c -s %k /tmp/dvb-adapter-%k.map`; if [ $rc != 0 ] ; then exit 0 ; else echo \
#	    \
#	    tbs9841:%k \
#	    \
#	    >> /tmp/dvb-adapter-%k.map; fi ; exit 0'"
#
#
# .conf file can be following:
# Tevii_S480 : 20
# tbs9841    : 22
# 
# Launching script will result with following symlinks
# /dev/dvb/adapterA -> /dev/dvb/adapter20
# /dev/dvb/adapterB -> /dev/dvb/adapter21
# /dev/dvb/adapterC -> /dev/dvb/adapter22
# /dev/dvb/adapterD -> /dev/dvb/adapter23
# /dev/dvb/adapterE -> /dev/dvb/adapter24
# /dev/dvb/adapterF -> /dev/dvb/adapter25
# where A&B are boot time adapters created by kernel for Tevii_S480
# while C,D,E,F are boot time adapters created by kernel for tbs9841




exec_prefix="/bin/"
map_file="/tmp/dvb-adapters.map"
conf_file="/etc/dvb-adapters-map.conf"
udev_rule="/etc/udev/rules.d/97-dvb-adapters-map.rules"


echo "DVB adapters mapping utility v1.2"
echo "Copyright: Piotr Oniszczuk"


if [ ! -e ${udev_rule} ] ; then
  echo "ERROR: \"${udev_rule}\" not installed !"
  echo "       Please install this file into /etc/udev/rules.d/"
  echo "       Now exiting..."
  exit 1
fi

if [ -z $1 ] ; then
  echo "Using boot time generated .map file"
else
  if [ $1 = "requery_udev" ] ; then
    echo "Asking udev for regeneration .map file..."
    ${exec_prefix}rm -rf ${map_file}
    ${exec_prefix}rm -rf /tmp/dvb-adapter-dvb*.map
    KERNEL_LIST=`${exec_prefix}ls -1 /sys/class/dvb/dvb* | grep "frontend0" | ${exec_prefix}sed "s/\://" 2>/dev/null`
    for adapter in ${KERNEL_LIST} ; do
      echo "    Querying ${adapter}"
      udevadm test ${adapter} > /dev/null 2> /dev/null
    done
  else
    echo "ERROR: Unknown commandline parameter. Exiting..."  	
  fi
fi

MAPS_LIST=`${exec_prefix}ls -1 /tmp/dvb-adapter-dvb*.map 2>/dev/null`
for file in ${MAPS_LIST} ; do
  ${exec_prefix}cat ${file} >> ${map_file}
done

${exec_prefix}rm -rf /tmp/dvb-adapter-dvb*.map 2>/dev/null

if [ ! -e ${map_file} ] ; then
  echo "ERROR: \"${map_file}\" not found !"
  echo "       You can regenerate this file by calling this sctipt"
  echo "       with \"requery_udev\" command-line parameter"
  echo "       Now exiting..."
  exit 1
fi

if [ ! -e ${conf_file} ] ; then
  echo "ERROR: Missing \"${conf_file}\" file !"
  echo "       You should put this file in /etc dir"
  echo "       Now exiting..."
  exit 1
fi

ADAPTERS_LIST=`${exec_prefix}cat ${map_file} 2>/dev/null`

${exec_prefix}mv ${map_file} ${map_file}.old

function DoSymlink() {
  if [ -z ${prefix} ] ; then
    path="/dev/dvb/${name}."
    prefix=1
  else
    path="/dev/dvb/adapter"
  fi
  for adapter in ${ADAPTERS_LIST} ; do
    rc=`echo ${adapter} | grep -s "${name}"`
    if /usr${exec_prefix}test ! -z "${rc}" ; then
      rc=`echo ${adapter} | ${exec_prefix}sed 's/.*dvb\([0-9]\)\.frontend.*/\1/'`
      echo "card_name:\"${name}\",kernel:adapter$rc->${path}${prefix}"
      ${exec_prefix}rm -rf ${path}${prefix}
      ${exec_prefix}ln -sf /dev/dvb/adapter$rc ${path}${prefix}
      prefix=$((${prefix} + 1))
    fi
  done
}

card_list=`${exec_prefix}cat ${conf_file} | ${exec_prefix}sed -e '/^#/ d' -e '/^$/ d' -e 's/ //g'`

for card in ${card_list} ; do
  name=`echo ${card} | ${exec_prefix}sed 's/\(.*\)\:.*/\1/'`
  prefix=`echo ${card} | ${exec_prefix}sed 's/.*:\([0-9]*\)/\1/'`
  DoSymlink
done

echo "All adapters mapped sucessfuly. Exiting..."
exit 0
