# ============================================================================
# modules/compute/user_data_manager.sh
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
    make

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
mkdir -p /opt/promata/{docker,configs,logs,backups,scripts}
chown -R ubuntu:ubuntu /opt/promata

# Initialize Docker Swarm as manager
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Save swarm join token for worker
docker swarm join-token worker | grep -E 'docker swarm join' > /opt/promata/swarm-join-command.txt

# Create Docker networks
docker network create --driver overlay promata_public
docker network create --driver overlay promata_internal
docker network create --driver overlay promata_database

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

# Create startup script
cat > /opt/promata/scripts/startup.sh << 'EOF'
#!/bin/bash
# Startup script for Pro-Mata manager node

# Wait for Docker to be ready
while ! docker info > /dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 5
done

# Ensure swarm mode is active
docker info | grep -q "Swarm: active" || docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Create networks if they don't exist
docker network ls | grep -q promata_public || docker network create --driver overlay promata_public
docker network ls | grep -q promata_internal || docker network create --driver overlay promata_internal
docker network ls | grep -q promata_database || docker network create --driver overlay promata_database

echo "Manager node startup completed"
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
echo "Manager node setup completed at $(date)" > /opt/promata/setup-completed.txt