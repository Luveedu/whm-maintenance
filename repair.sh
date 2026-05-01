#!/bin/bash

# Function to execute a command with a 2-second delay
execute_with_delay() {
    echo -e "\n=================================================="
    echo "Executing: $1"
    echo "=================================================="
    eval "$1"
    sleep 2
}

echo "Starting Server Repair Process..."

# 1. Clear Logs via remote script
execute_with_delay 'wget -qO- https://raw.githubusercontent.com/Luveedu/clear-whm-logs/refs/heads/main/clear.sh | bash'

# 2. Optional cPanel Update
echo ""
read -p "Would you like to update cPanel Files? [y/N]: " update_cp
if [[ "$update_cp" =~ ^[Yy]$ ]]; then
    execute_with_delay '/scripts/upcp --force'
else
    echo "Skipping cPanel update..."
    sleep 2
fi

# 3. Restart cpsrvd
execute_with_delay 'find /var/cpanel/sessions/raw/ -type f -delete'
execute_with_delay '/scripts/restartsrv_cpsrvd'

# 4. Check and fix cPanel packages
execute_with_delay '/usr/local/cpanel/scripts/check_cpanel_pkgs --fix'

# 5. Optional Cloudlinux/Imunify Beta Repo Updates
echo ""
read -p "Would you like to Update using Cloudlinux Beta Repo? [y/N]: " beta_repo
CL_FLAG=""
IM_FLAG=""

if [[ "$beta_repo" =~ ^[Yy]$ ]]; then
    CL_FLAG="--enablerepo=cloudlinux-updates-testing"
    IM_FLAG="--enablerepo=imunify360-testing"
    echo "Beta repositories enabled for this update run."
    sleep 2
fi

execute_with_delay 'yum clean all'
execute_with_delay 'yum check-update'
execute_with_delay "yum update $CL_FLAG -y"
execute_with_delay "yum groupupdate alt-php $CL_FLAG -y"
execute_with_delay "yum update imunify360-firewall $IM_FLAG -y"

# 6. Restart all cPanel services
echo -e "\n=================================================="
echo "Restarting all cPanel services..."
echo "=================================================="
for svc in /usr/local/cpanel/scripts/restartsrv_*; do
    if [ -x "$svc" ]; then
        echo "Running: $svc"
        "$svc"
        sleep 2
    fi
done

# 7. RCS License Renew
execute_with_delay 'bash <(curl -s https://raw.githubusercontent.com/Luveedu/RCS-License-Renew/refs/heads/main/continue.sh)'

# 8. Public Resolver Change
execute_with_delay 'curl -sSL https://raw.githubusercontent.com/Luveedu/Public-Resolver-Change/refs/heads/main/nsetup.sh | sudo bash'

# 9. Restart all cPanel services again
echo -e "\n=================================================="
echo "Restarting all cPanel services (Second Pass)..."
echo "=================================================="
for svc in /usr/local/cpanel/scripts/restartsrv_*; do
    if [ -x "$svc" ]; then
        echo "Running: $svc"
        "$svc"
        sleep 2
    fi
done

# 10. RCS License Renew (Second Pass)
execute_with_delay 'bash <(curl -s https://raw.githubusercontent.com/Luveedu/RCS-License-Renew/refs/heads/main/continue.sh)'

echo -e "\n=================================================="
echo "Repair process completed successfully!"
echo "=================================================="