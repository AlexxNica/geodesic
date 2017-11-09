# Sync the clock in the Docker Virtual Machine to the system's hardware clock to avoid time drift
# (Only works in privileged mode)
hwclock -s >/dev/null 2>&1 
if [ $? -ne 0 ]; then
  echo "* Failed to sync system time"
fi
