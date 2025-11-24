# ============================================================================
# modules/compute/user_data_worker.sh  
# ============================================================================
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    jq \
    htop \
    make \
    postgresql-client

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Docker Compose (standalone)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Format and mount additional EBS volume
while [ ! -e /dev/nvme1n1 ]; do sleep 1; done
mkfs.ext4 /dev/nvme1n1
mkdir -p /opt/promata
mount /dev/nvme1n1 /opt/promata
echo '/dev/nvme1n1 /opt/promata ext4 defaults,nofail 0 2' >> /etc/fstab
chown ubuntu:ubuntu /opt/promata

# Create directory structure
mkdir -p /opt/promata/{docker,configs,logs,backups,scripts,data}
mkdir -p /opt/promata/data/{postgres,redis,uploads}
chown -R ubuntu:ubuntu /opt/promata

# Set up log rotation for Docker
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker

# Install monitoring agent (CloudWatch)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Setup CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "ProMata/${project_name}",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/aws/ec2/${project_name}-${environment}/syslog"
          },
          {
            "file_path": "/opt/promata/logs/*.log",
            "log_group_name": "/aws/ec2/${project_name}-${environment}/application"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create worker join script (will be executed by Ansible or manually)
cat > /opt/promata/scripts/join-swarm.sh << 'EOF'
#!/bin/bash
# Script to join Docker Swarm

MANAGER_IP="${manager_ip}"
MAX_RETRIES=30
RETRY_COUNT=0

echo "Attempting to join Docker Swarm with manager at $MANAGER_IP"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try to get join token from manager
    JOIN_TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@$MANAGER_IP "docker swarm join-token worker -q" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$JOIN_TOKEN" ]; then
        echo "Successfully retrieved join token"
        
        # Join the swarm
        docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377
        
        if [ $? -eq 0 ]; then
            echo "Successfully joined Docker Swarm"
            exit 0
        else
            echo "Failed to join swarm, retrying..."
        fi
    else
        echo "Failed to retrieve join token, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 10
done

echo "Failed to join Docker Swarm after $MAX_RETRIES attempts"
exit 1
EOF

chmod +x /opt/promata/scripts/join-swarm.sh

# Create startup script
cat > /opt/promata/scripts/startup.sh << 'EOF'
#!/bin/bash
# Startup script for Pro-Mata worker node

# Wait for Docker to be ready
while ! docker info > /dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 5
done

# Check if already part of swarm
if ! docker info | grep -q "Swarm: active"; then
    echo "Not part of swarm, attempting to join..."
    /opt/promata/scripts/join-swarm.sh
fi

echo "Worker node startup completed"
EOF

chmod +x /opt/promata/scripts/startup.sh

# Create systemd service for startup script
cat > /etc/systemd/system/promata-startup.service << EOF
[Unit]
Description=Pro-Mata Startup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/promata/scripts/startup.sh
RemainAfterExit=yes
StandardOutput=journal
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl enable promata-startup.service

# Signal that user data script completed
echo "Worker node setup completed at $(date)" > /opt/promata/setup-completed.txt