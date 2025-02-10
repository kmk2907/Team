provider "aws" {
  region = "ap-northeast-2" # 서울 리전
}

# 보안 그룹 생성 (80번 포트와 22번 포트 허용)
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-security-group"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP에서 HTTP 접속 허용
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP에서 SSH 접속 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # 모든 트래픽 아웃바운드 허용
  }
}

# EC2 인스턴스 생성 (t2.micro)
resource "aws_instance" "test-web" {
  ami           = "넣고싶은 이미지" # Amazon Linux 2 AMI (서울 리전)
  instance_type = "t2.micro"
  key_name      = "soldesk_Key"           # 사용자의 키페어

  security_groups = [aws_security_group.nginx_sg.name] # 생성한 보안 그룹 적용

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>안녕?</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Terraform-Nginx-Server"
  }
}
