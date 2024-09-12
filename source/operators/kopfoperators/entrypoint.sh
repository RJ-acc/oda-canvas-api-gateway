#!/bin/sh

# Initialize the previous content to track changes
PREVIOUS_CONTENT=""

# Function to run the command based on the ConfigMap content
run_command() {
  # Check if the ConfigMap file exists and is non-empty
  if [ -s /config/run-command/run-command ]; then
    # Read the content of the ConfigMap
    CONFIG_CONTENT=$(cat /config/run-command/run-command)
    PREVIOUS_CONTENT="$CONFIG_CONTENT"
  else
    # Default behavior if ConfigMap is missing or empty
    CONFIG_CONTENT=""
    echo "ConfigMap not found or empty, running default command."
  fi

  # Determine the command based on the content
  if echo "$CONFIG_CONTENT" | grep -q "apiOperatorKong"; then
    CMD="kopf run --namespace=components componentOperator/componentOperator.py apiOperatorIstio/apiOperatorIstiowithKong.py securityController/securityControllerKeycloak.py apiOperatorKong/apiOperatorKong.py"
  elif echo "$CONFIG_CONTENT" | grep -q "apiOperatorApisix"; then
    CMD="kopf run --namespace=components componentOperator/componentOperator.py apiOperatorIstio/apiOperatorIstiowithApisix.py securityController/securityControllerKeycloak.py apiOperatorKong/apiOperatorApisix.py"
  else
    CMD="kopf run --namespace=components componentOperator/componentOperator.py apiOperatorIstio/apiOperatorIstio.py securityController/securityControllerKeycloak.py"
  fi

  echo "Running command: $CMD"
  sh -c "$CMD" &
  KOPF_PID=$!
  echo "KOPF_PID is $KOPF_PID"
}

# Ensure that the previous process is terminated before starting a new one
terminate_previous_kopf() {
  if [ -n "$KOPF_PID" ] && kill -0 "$KOPF_PID" > /dev/null 2>&1; then
    echo "Terminating previous kopf process with PID $KOPF_PID"
    kill -TERM "$KOPF_PID"
    wait "$KOPF_PID"
  fi
}

# Ensure the default command runs if the ConfigMap is not found
if [ ! -f /config/run-command/run-command ]; then
  echo "No ConfigMap found initially, running default command."
  run_command
else
  # Run the initial command based on the content (if the file exists)
  run_command
fi

# Watch for changes to the ConfigMap data and restart the command only if the content changes
while true; do
  # Use `inotifywait` to wait for the ConfigMap file to be created if it doesn't exist
  if [ ! -f /config/run-command/run-command ]; then
    echo "Waiting for ConfigMap file to be created..."
    inotifywait -e create /config/run-command
    echo "ConfigMap file detected. Checking content and running command."
    
    # Immediately check content and run based on conditions after the creation of the ConfigMap
    terminate_previous_kopf
    run_command
  fi

  # Start watching for changes once the file is detected
  inotifywait -e modify /config/run-command/run-command
  echo "ConfigMap changed, checking for content update..."

  # Recheck the ConfigMap content
  if [ -s /config/run-command/run-command ]; then
    NEW_CONTENT=$(cat /config/run-command/run-command)
  else
    NEW_CONTENT=""
  fi

  # Only restart the command if the content has actually changed
  if [ "$NEW_CONTENT" != "$PREVIOUS_CONTENT" ]; then
    echo "Content has changed, reloading kopf process..."

    # Terminate the previous kopf process
    terminate_previous_kopf

    # Update the content
    PREVIOUS_CONTENT="$NEW_CONTENT"

    # Run the new command based on the updated content
    run_command
  else
    echo "No content changes detected, skipping restart."
  fi
done
