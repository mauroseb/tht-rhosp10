#!/bin/bash

export THT=/home/stack/templates
export LOG=logs/deploy_$(date +%F_%s).log
export OUTPUT=logs/output_$(date +%F_%s).log
export NETBOT_SEND=./netbot-send.py

[ -w deploy_nr.txt ] && echo $(( $(cat deploy_nr.txt) + 1 )) > deploy_nr.txt || echo 1 > deploy_nr.txt

echodo () {

   echo "======================================================== " >> deploy_attempts.log
   echo "Deploy attempt #$(cat deploy_nr.txt) $( date '+%F %T' ) " >> deploy_attempts.log
   echo "======================================================== " >> deploy_attempts.log
   echo "$*" >> deploy_attempts.log
   eval $*
   if [ $? -ne 0 ]; then
        echo "FAILURES:" >> deploy_attempts.log
        openstack stack failures list --long overcloud >> deploy_attempts.log
        #echo "YOUR DEPLOYMENT FAILED AGAIN!" | ssh stack@192.168.122.1 espeak-ng -s 160

        [[ -x $NETBOT_SEND ]] && $NETBOT_SEND "Deploy $DEPLOY_NR failed!"
   else
        echo "SUCCESFUL!" >> deploy_attempts.log
        #echo "YOU HAVE CHOSEN WISELY!" | ssh stack@192.168.122.1 espeak-ng -s 160
        [[ -x $NETBOT_SEND ]] && $NETBOT_SEND "Deploy $DEPLOY_NR succeeded!"
   fi
   echo "======================================================== " >> deploy_attempts.log
}

touch $LOG
rm last.log
ln -s $LOG last.log

echodo time openstack overcloud deploy \
        --timeout 240 \
        --libvirt-type kvm \
        --templates /usr/share/openstack-tripleo-heat-templates \
        --ntp-server clock1.rdu2.redhat.com \
        --control-flavor controller --control-scale 1 \
        --compute-flavor compute --compute-scale 1 \
        --ceph-storage-flavor ceph --ceph-storage-scale 1 \
        --neutron-tunnel-types vxlan --neutron-network-type vxlan \
        -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
        -e ${THT}/00-common.yaml \
        -e ${THT}/01-storage-env.yaml \
        -e ${THT}/02-network-env.yaml \
        -e ${THT}/03-predictable-hostnames.yaml \
        -e ${THT}/04-predictable-ips.yaml \
        -e ${THT}/05-bond-fix.yaml \
        -e ${THT}/06-monitoring.yaml \
        -e ${THT}/07-logging.yaml \
        -e ${THT}/08-post-hook.yaml \
        -e ${THT}/09-cadf.yaml \
        --log-file $LOG | tee -a $OUTPUT

