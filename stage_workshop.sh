{\rtf1\ansi\ansicpg1252\cocoartf1671\cocoasubrtf600
{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww10800\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/bin/bash\
\
WORKSHOPS=(\'93X-Ray Lab" \\\
"Quit")\
\
function remote_exec \{\
  sshpass -p $MY_PE_PASSWORD ssh -o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null nutanix@$MY_PE_HOST "$@"\
\}\
\
function send_file \{\
  FILENAME="$\{1##*/\}"\
\
  sshpass -p $MY_PE_PASSWORD scp -o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null "$1" nutanix@$MY_PE_HOST:/home/nutanix/"$\{FILENAME\}"\
\}\
\
function acli \{\
  remote_exec /usr/local/nutanix/bin/acli "$@"\
\}\
\
# Get list of clusters from user\
function get_file \{\
  read -p 'Cluster Input File: ' CLUSTER_LIST\
\
  if [ ! -f $\{CLUSTER_LIST\} ]; then\
    echo "FILE DOES NOT EXIST!"\
    get_file\
  fi\
\
  select_workshop\
\}\
\
# Get workshop selection from user, set script files to send to remote clusters\
function select_workshop \{\
  PS3='Select an option: '\
  select WORKSHOP in "$\{WORKSHOPS[@]\}"\
  do\
    case $WORKSHOP in\
      \'93X-Ray Lab\'94)\
      PE_CONFIG=stage_xray.sh\
      break\
      ;;\
      "Quit")\
      exit\
      ;;\
      *) echo "Invalid entry, please try again.";;\
    esac\
  done\
\
  read -p "Are you sure you want to stage $\{WORKSHOP\} to the clusters in $\{CLUSTER_LIST\}? Your only 'undo' option is running Foundation on your cluster(s) again. (Y/N)" -n 1 -r\
\
  if [[ $REPLY =~ ^[Yy]$ ]]; then\
    echo\
    stage_clusters\
  else\
    echo\
    echo "Come back soon!"\
  fi\
\}\
\
# Set script files to send to remote clusters based on command line argument\
function set_workshop \{\
\
  case $\{WORKSHOPS[$(($\{WORKSHOP_NUM\}-1))]\} in\
    \'93X-Ray Lab\'94)\
    PE_CONFIG=stage_xray.sh\
    ;;\
    *) echo "No one should ever see this. Time to panic.";;\
  esac\
\
  stage_clusters\
\}\
\
# Send configuration scripts to remote clusters and execute Prism Element script\
function stage_clusters \{\
  for MY_LINE in `cat $\{CLUSTER_LIST\} | grep -v ^#`\
  do\
    set -f\
    array=($\{MY_LINE//|/ \})\
    MY_PE_HOST=$\{array[0]\}\
    MY_PE_PASSWORD=$\{array[1]\}\
\
    # Distribute configuration scripts\
    echo "Sending configuration script(s) to $\{MY_PE_HOST\}"\
    send_file scripts/$\{PE_CONFIG\}\
    if [ ! -z $\{PC_CONFIG\} ]; then\
      send_file scripts/$\{PC_CONFIG\}\
    fi\
    # Execute that file asynchroneously remotely (script keeps running on CVM in the background)\
    echo "Executing configuration script on $\{MY_PE_HOST\}"\
    remote_exec "MY_PE_PASSWORD=$\{MY_PE_PASSWORD\} nohup bash /home/nutanix/$\{PE_CONFIG\} >> config.log 2>&1 &"\
  done\
\
  echo "Progress of individual clusters can be monitored by SSHing to the cluster's virtual IP and running 'tail -f /home/nutanix/config.log'."\
  exit\
\}\
\
function validate_clusters \{\
  for MY_LINE in `cat $\{CLUSTER_LIST\} | grep -v ^#`\
  do\
    set -f\
    array=($\{MY_LINE//|/ \})\
    MY_PE_HOST=$\{array[0]\}\
    MY_PE_PASSWORD=$\{array[1]\}\
    array=($\{MY_PE_HOST//./ \})\
    MY_HPOC_NUMBER=$\{array[2]\}\
\
    if [[ $(acli vm.list) =~ "STAGING-FAILED" ]]; then\
      echo -e "\\e[1;31m$\{MY_PE_HOST\} - Image staging FAILED\\e[0m"\
      echo $\{MY_PE_HOST\} - Review log at $\{MY_PE_HOST\}:/home/nutanix/config.log\
    else\
      echo -e "\\e[1;32m$\{MY_PE_HOST\} - Staging successful!"\
    fi\
  done\
  exit\
\}\
\
# Display script usage\
function usage \{\
  cat << EOF\
\
  Interactive Usage:        stage_workshop\
  Non-interactive Usage:    stage_workshop -f cluster_list_file -w workshop_number\
\
  Available Workshops:\
  1) NHT Foundation Lab\
\
EOF\
exit\
\}\
\
# Check if file passed via command line, otherwise prompt for cluster list file\
while getopts ":f:w:" opt; do\
  case $\{opt\} in\
    f )\
    if [ -f $\{OPTARG\} ]; then\
      CLUSTER_LIST=$\{OPTARG\}\
    else\
      echo "FILE DOES NOT EXIST!"\
      usage\
    fi\
    ;;\
    w )\
    if [ $(($OPTARG)) -gt 0 ] && [ $(($OPTARG)) -le $(($\{#WORKSHOPS[@]\}-3)) ]; then\
      # do something\
      WORKSHOP_NUM=$\{OPTARG\}\
    else\
      echo "INVALID WORKSHOP SELECTION!"\
      usage\
    fi\
    ;;\
    \\? ) usage;;\
  esac\
done\
shift $((OPTIND -1))\
\
if [ ! -z $\{CLUSTER_LIST\} ] && [ ! -z $\{WORKSHOP_NUM\} ]; then\
  # If file and workshop selections are valid, begin staging clusters\
  set_workshop\
elif [ ! -z $\{CLUSTER_LIST\} ] || [ ! -z $\{WORKSHOP_NUM\} ]; then\
  echo "MISSING ARGUMENTS!"\
  usage\
else\
  # If no command line arguments, start interactive session\
  get_file\
fi\
\
}