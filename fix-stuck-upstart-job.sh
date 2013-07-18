#!/bin/bash

# Author: Brian Lloyd
#
# Usage: ./fix-stuck-upstart.sh [job]
#
# When an upstart init script uses fork or daemon, but the config
# has an error in it causing the process not to fork as expected, 
# it can cause problems with stopping the job - the job gets stuck
# in a stopped/killed or start/killed state, but the process ID listed
# is no longer running.  The job (config) name must be changed or
# often a reboot is required to clear out the "stuck" job status.
#
# This script creates background sleep processes until one of them 
# takes on the PID of the stuck job and then exits, allowing the 
# sleep process to end on its own, and allowing upstart to clear 
# the job status as it sees the background sleep process end.
#
# I don't claim to understand exactly why this works, but it seems 
# to work every time, at least on CentOS 6 where I've tested it.

targetprocess=$1
targetpid=`status $1 | egrep -o '[0-9]+$'`
if ! [[ "$targetpid" =~ ^[0-9]+$ ]]
then
  echo "Couldn't get PID for $targetprocess from upstart (status $targetprocess)"
  exit 1
fi

start $targetprocess 2>&1 1>/dev/null &
tmp=$!
sleep 1
kill $tmp 2>&1 1>/dev/null
stop $targetprocess &
upstartpid=$!

echo -n "Starting dummy process for process $targetprocess, PID $targetpid"
while [[ 1 ]]
do
  {
  sleep 2
  } &
  pid=$!
  if [[ $(($pid % 1000)) -eq 0 ]]
  then
    echo -n "."
  fi
  if [[ $pid -ne $targetpid ]]
  then
    kill $pid 2>&1 1>/dev/null
  else
    echo "Done"
    echo "Upstart should report the process as 'stop/waiting' in about 2 seconds"
    exit
  fi
done 2>/dev/null
