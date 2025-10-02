terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-terraform"
  }
}

# Subnet Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # Ajuste conforme sua região
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-terraform"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "rt-public-terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-terraform-sg"
  description = "Security group para instancia EC2"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ATENÇÃO: Restrinja isso ao seu IP em produção
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de entrada - Flask (porta 5000)
  ingress {
    description = "Flask"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-terraform-sg"
  }
}

# EC2
resource "aws_instance" "minha_instancia" {
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  key_name = "aws-keypair"
  
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Atualiza sistema
              apt update -y
              apt install -y python3-pip python3-venv git nginx
              
              # Clone o repositório Flask usando token
              cd /home/ubuntu
              git clone https://${var.github_token}@github.com/Coletinn/hello-flask.git
              cd hello-flask
              
              # Configura ambiente virtual e instala dependências
              python3 -m venv venv
              source venv/bin/activate
              pip install flask
              
              # Ajusta permissões
              chown -R ubuntu:ubuntu /home/ubuntu/hello-flask
              
              # Cria serviço systemd para Flask
              cat > /etc/systemd/system/flask-app.service <<'SERVICE'
              [Unit]
              Description=Flask Hello App
              After=network.target
              
              [Service]
              User=ubuntu
              WorkingDirectory=/home/ubuntu/hello-flask
              Environment="PATH=/home/ubuntu/hello-flask/venv/bin"
              ExecStart=/home/ubuntu/hello-flask/venv/bin/python app.py
              Restart=always
              
              [Install]
              WantedBy=multi-user.target
              SERVICE
              
              # Configura Nginx como proxy reverso
              cat > /etc/nginx/sites-available/flask-app <<'NGINX'
              server {
                  listen 80;
                  server_name _;
                  
                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  }
              }
              NGINX
              
              # Ativa configuração Nginx
              ln -sf /etc/nginx/sites-available/flask-app /etc/nginx/sites-enabled/
              rm -f /etc/nginx/sites-enabled/default
              
              # Inicia serviços
              systemctl daemon-reload
              systemctl start flask-app
              systemctl enable flask-app
              systemctl restart nginx
              
              # Log de sucesso
              echo "Deploy concluído com sucesso!" > /home/ubuntu/deploy.log
              EOF

  tags = {
    Name = "Minha-Instancia-Terraform"
    Ambiente = "Desenvolvimento"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
}

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.minha_instancia.id
}

output "instance_public_ip" {
  description = "IP público da instância"
  value       = aws_instance.minha_instancia.public_ip
}

output "instance_public_dns" {
  description = "DNS público da instância"
  value       = aws_instance.minha_instancia.public_dns
}

output "ssh_command" {
  description = "Comando para conectar via SSH"
  value       = "ssh -i aws-keypair.pem ubuntu@${aws_instance.minha_instancia.public_ip}"
}

output "app_url" {
  description = "URL da aplicação Flask"
  value       = "http://${aws_instance.minha_instancia.public_ip}"
}

output "app_url_direct" {
  description = "URL direta Flask (porta 5000)"
  value       = "http://${aws_instance.minha_instancia.public_ip}:5000"
}
