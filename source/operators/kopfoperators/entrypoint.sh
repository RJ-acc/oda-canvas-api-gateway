#!/bin/sh
run_command() {
  CMD=$(cat /config/run-command)
  echo "Running command: $CMD"
  
  sh -c "$CMD" &
  KOPF_PID=$!
  echo "KOPF_PID is $KOPF_PID"
  
  if ! kill -0 $KOPF_PID > /dev/null 2>&1; then
    echo "Failed to start kopf process"
    exit 1
  fi
}

run_command

#Watching for changes to the ConfigMap data and restarting the command if it see any changes
while true; do
  inotifywait -e modify /config/run-command
  echo "ConfigMap changed, reloading kopf with updated operators..."
  kill -TERM $KOPF_PID
  wait $KOPF_PID
  run_command
done
