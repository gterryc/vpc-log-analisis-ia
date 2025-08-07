# modules/demo/main.tf

# AMI más reciente de Amazon Linux 2
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# User Data para servidor web normal
locals {
  web_server_user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    # Crear contenido web simple
    cat > /var/www/html/index.html << 'HTML'
    <html>
      <head><title>Demo Server</title></head>
      <body>
        <h1>Servidor Demo - Detección de Anomalías</h1>
        <p>Este servidor genera tráfico normal para la demo.</p>
        <p>Timestamp: $(date)</p>
      </body>
    </html>
HTML
    
    # Script para generar tráfico normal
    cat > /home/ec2-user/generate_normal_traffic.sh << 'SCRIPT'
    #!/bin/bash
    echo "Iniciando generación de tráfico normal..."
    while true; do
        # Simular tráfico HTTP normal
        curl -s http://localhost/ > /dev/null
        sleep $((RANDOM % 10 + 5))
        
        # Simular algunas consultas DNS
        nslookup google.com > /dev/null
        sleep $((RANDOM % 15 + 10))
    done
SCRIPT
    
    chmod +x /home/ec2-user/generate_normal_traffic.sh
    
    # Ejecutar como servicio
    cat > /etc/systemd/system/normal-traffic.service << 'SERVICE'
[Unit]
Description=Normal Traffic Generator
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/home/ec2-user/generate_normal_traffic.sh
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE
    
    systemctl daemon-reload
    systemctl enable normal-traffic
    systemctl start normal-traffic
  EOF
  )
  
  # User Data para simulador de ataques
  attack_simulator_user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip nmap
    
    # Script de Port Scanning
    cat > /home/ec2-user/port_scanner.py << 'PYTHON'
import socket
import threading
import time
import random
import sys

def scan_port(target, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.1)
        result = sock.connect_ex((target, port))
        sock.close()
        if result == 0:
            print(f"Port {port} is open on {target}")
    except:
        pass

def port_scan_attack(target, duration=300):
    print(f"Iniciando port scan contra {target} por {duration} segundos")
    end_time = time.time() + duration
    
    while time.time() < end_time:
        port = random.randint(1, 65535)
        threading.Thread(target=scan_port, args=(target, port)).start()
        time.sleep(0.01)  # Para no sobrecargar

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.1.100"
    port_scan_attack(target)
PYTHON

    # Script de DDoS
    cat > /home/ec2-user/ddos_simulator.py << 'PYTHON'
import threading
import socket
import time
import sys

def ddos_thread(target, port, duration):
    end_time = time.time() + duration
    while time.time() < end_time:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((target, port))
            sock.send(b"GET / HTTP/1.1\r\nHost: " + target.encode() + b"\r\n\r\n")
            sock.close()
        except:
            pass
        time.sleep(0.001)

def ddos_attack(target, port=80, threads=100, duration=300):
    print(f"Iniciando DDoS contra {target}:{port} con {threads} threads por {duration} segundos")
    
    for i in range(threads):
        thread = threading.Thread(target=ddos_thread, args=(target, port, duration))
        thread.daemon = True
        thread.start()
    
    time.sleep(duration)

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.1.100"
    ddos_attack(target)
PYTHON

    # Script de Data Exfiltration
    cat > /home/ec2-user/data_exfiltration.py << 'PYTHON'
import requests
import time
import random
import sys

def simulate_data_exfiltration(target, duration=300):
    print(f"Simulando exfiltración de datos hacia {target} por {duration} segundos")
    end_time = time.time() + duration
    
    # Generar datos aleatorios grandes
    large_data = "X" * (1024 * 1024)  # 1MB de datos
    
    while time.time() < end_time:
        try:
            # Simular POST de datos grandes
            requests.post(f"http://{target}/upload", data=large_data, timeout=1)
        except:
            pass
        time.sleep(random.randint(1, 5))

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.1.100"
    simulate_data_exfiltration(target)
PYTHON

    # Script maestro para controlar ataques
    cat > /home/ec2-user/attack_controller.sh << 'SCRIPT'
#!/bin/bash

TARGET_IP="10.0.1.100"  # IP del servidor web

echo "=== Controlador de Ataques para Demo ==="
echo "Target: $TARGET_IP"
echo ""
echo "Opciones:"
echo "1. Port Scan Attack"
echo "2. DDoS Attack"
echo "3. Data Exfiltration"
echo "4. All Attacks (secuencial)"
echo "5. Stop all attacks"

case $1 in
    1|"port")
        echo "Iniciando Port Scan Attack..."
        python3 /home/ec2-user/port_scanner.py $TARGET_IP &
        echo $! > /tmp/port_scan.pid
        ;;
    2|"ddos")
        echo "Iniciando DDoS Attack..."
        python3 /home/ec2-user/ddos_simulator.py $TARGET_IP &
        echo $! > /tmp/ddos.pid
        ;;
    3|"exfil")
        echo "Iniciando Data Exfiltration..."
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP &
        echo $! > /tmp/exfil.pid
        ;;
    4|"all")
        echo "Iniciando todos los ataques secuencialmente..."
        # Port scan por 2 minutos
        python3 /home/ec2-user/port_scanner.py $TARGET_IP &
        PORT_PID=$!
        sleep 120
        kill $PORT_PID 2>/dev/null
        
        # DDoS por 2 minutos
        python3 /home/ec2-user/ddos_simulator.py $TARGET_IP &
        DDOS_PID=$!
        sleep 120
        kill $DDOS_PID 2>/dev/null
        
        # Data exfiltration por 2 minutos
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP &
        EXFIL_PID=$!
        sleep 120
        kill $EXFIL_PID 2>/dev/null
        ;;
    5|"stop")
        echo "Deteniendo todos los ataques..."
        pkill -f "port_scanner.py"
        pkill -f "ddos_simulator.py" 
        pkill -f "data_exfiltration.py"
        rm -f /tmp/*.pid
        ;;
    *)
        echo "Uso: $0 [1|2|3|4|5] o [port|ddos|exfil|all|stop]"
        exit 1
        ;;
esac
SCRIPT
    
    chmod +x /home/ec2-user/attack_controller.sh
    chown ec2-user:ec2-user /home/ec2-user/*.py
    chown ec2-user:ec2-user /home/ec2-user/*.sh
  EOF
  )
}

# Instancia del servidor web (target)
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_server.id]
  subnet_id              = var.private_subnet_id
  
  user_data = local.web_server_user_data
  
  tags = merge(var.tags, {
    Name = "demo-web-server"
    Role = "Target"
    Purpose = "NormalTrafficGenerator"
  })
}

# Instancia del simulador de ataques
resource "aws_instance" "attack_simulator" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.attack_simulator.id]
  subnet_id              = var.public_subnet_id
  
  user_data = local.attack_simulator_user_data
  
  tags = merge(var.tags, {
    Name = "demo-attack-simulator"
    Role = "Attacker"
    Purpose = "AttackSimulator"
  })
}

# Security Group para servidor web
resource "aws_security_group" "web_server" {
  name_prefix = "demo-web-server-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Permitir todos los puertos para la demo (para simular port scanning)
  ingress {
    description = "All ports for demo"
    from_port   = 1
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "demo-web-server-sg"
  })
}

# Security Group para simulador de ataques
resource "aws_security_group" "attack_simulator" {
  name_prefix = "demo-attack-simulator-"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "demo-attack-simulator-sg"
  })
}

# Elastic IP para el simulador de ataques (para acceso SSH)
resource "aws_eip" "attack_simulator" {
  instance = aws_instance.attack_simulator.id
  domain   = "vpc"
  
  tags = merge(var.tags, {
    Name = "demo-attack-simulator-eip"
  })
}

# Output para mostrar IPs y comandos útiles
output "demo_info" {
  value = {
    web_server_private_ip = aws_instance.web_server.private_ip
    attack_simulator_public_ip = aws_eip.attack_simulator.public_ip
    attack_simulator_private_ip = aws_instance.attack_simulator.private_ip
    
    ssh_command = "ssh -i your-key.pem ec2-user@${aws_eip.attack_simulator.public_ip}"
    
    attack_commands = {
      port_scan = "./attack_controller.sh port",
      ddos = "./attack_controller.sh ddos", 
      data_exfiltration = "./attack_controller.sh exfil",
      all_attacks = "./attack_controller.sh all",
      stop_attacks = "./attack_controller.sh stop"
    }
  }
}