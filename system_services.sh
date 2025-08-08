
#!/bin/bash

echo "Checking status of all systemd services..."
echo "-------------------------------------------"

# List all services and check their status
systemctl list-units --type=service --all | while read -r line; do
    service_name=$(echo "$line" | awk '{print $1}')
    if [[ $service_name == *.service ]]; then
        status=$(systemctl is-active "$service_name")
        echo "$service_name : $status"
    fi
done
