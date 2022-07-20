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





map_file="/tmp/dvb-adapters.map"
conf_file="/etc/dvb-mapper/dvb-names-mapping.conf"
wait_list="/etc/dvb-mapper/dvb-wait-list.conf"
udev_rule="/etc/udev/rules.d/97-dvb-mapper.rules"
timeout=10

echo "dvb-mapper: DVB adapters mapping utility v1.0"
echo "dvb-mapper: Copyright: Piotr Oniszczuk"


if [ ! -e ${udev_rule} ] ; then
  echo "ERROR: \"${udev_rule}\" not installed !"
  echo "       Please install this file into /etc/udev/rules.d/"
  echo "       Now exiting..."
  exit 1
fi

wait_lst=`cat ${wait_list} | sed -e '/^#/ d' -e '/^$/ d' -e 's/ //g'`
for device in ${wait_lst} ; do
  i=0
  while [ $i -lt ${timeout} ] ; do
    i=$((${i} + 1))
    if [ -e ${device} ] ; then
      i=${timeout}
      echo "dvb-mapper: awaited tuner [${device}] present ..."
      break
    else
      if [ $i -ge ${timeout} ] ; then
        echo "dvb-mapper: timeout waiting for tuner [${device}] !"
        exit 1
      else
        /bin/sleep 1
      fi
    fi
  done
done

if [ -z $1 ] ; then
  echo "dvb-mapper: using boot time udev generated .map files"
else
  if [ $1 = "requery_udev" ] ; then
    echo "Asking udev for regeneration .map file..."
    rm -rf ${map_file}
    rm -rf /tmp/dvb-adapter-dvb*.map
    KERNEL_LIST=`ls -1 /sys/class/dvb/dvb* | grep "frontend0" | sed "s/\://" 2>/dev/null`
    for adapter in ${KERNEL_LIST} ; do
      echo "    Querying ${adapter}"
      udevadm test ${adapter} > /dev/null 2> /dev/null
    done
  else
    echo "ERROR: Unknown commandline parameter. Exiting..."  	
  fi
fi

MAPS_LIST=`ls -1 /tmp/dvb-adapter-dvb*.map 2>/dev/null`
for file in ${MAPS_LIST} ; do
  cat ${file} >> ${map_file}
done
rm -rf /tmp/dvb-adapter-dvb*.map

if [ ! -e ${map_file} ] ; then
  if [ ! -e ${map_file}.mapped ] ; then
    echo "dvb-mapper: it looks like tuners are already mapped ..."
    exit 0
  else
    echo "ERROR: \"${map_file}\" not found !"
    echo "       You can regenerate this file by calling this sctipt"
    echo "       with \"requery_udev\" command-line parameter"
    echo "       Now exiting..."
    exit 1
  fi
fi

if [ ! -e ${conf_file} ] ; then
  echo "ERROR: Missing \"${conf_file}\" file !"
  echo "       You should put this file in /etc dir"
  echo "       Now exiting..."
  exit 1
fi

ADAPTERS_LIST=`cat ${map_file} 2>/dev/null`

mv ${map_file} ${map_file}.mapped

function DoSymlink() {
  if [ -z ${prefix} ] ; then
    path="/dev/dvb/${name}."
    prefix=1
  else
    path="/dev/dvb/adapter"
  fi
  for adapter in ${ADAPTERS_LIST} ; do
    rc=`echo ${adapter} | grep -s "${name}"`
    if /usr/bin/test ! -z "${rc}" ; then
      rc=`echo ${adapter} | sed 's/.*dvb\([0-9]\)\.frontend.*/\1/'`
      echo "dvb-mapper: card_name:\"${name}\",kernel:adapter$rc->${path}${prefix}"
      rm -rf ${path}${prefix}
      ln -sf /dev/dvb/adapter$rc ${path}${prefix}
      prefix=$((${prefix} + 1))
    fi
  done
}

card_list=`cat ${conf_file} | sed -e '/^#/ d' -e '/^$/ d' -e 's/ //g'`

for card in ${card_list} ; do
  name=`echo ${card} | sed 's/\(.*\)\:.*/\1/'`
  prefix=`echo ${card} | sed 's/.*:\([0-9]*\)/\1/'`
  DoSymlink
done

echo "dvb-mapper: all adapters mapped sucessfuly ..."
exit 0
