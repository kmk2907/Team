provider "aws" {
  region = "ap-northeast-2"
}

# VPC 생성
resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
}

# 서브넷 생성 (멀티 AZ)
resource "aws_subnet" "test-subnet-1" {
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "test-subnet-2" {
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id
}

# 라우팅 테이블 설정
resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id
}

resource "aws_route" "internet-access" {
  route_table_id         = aws_route_table.test-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test-igw.id
}

# RDS(Aurora MySQL) 클러스터 생성
resource "aws_rds_cluster" "test-db" {
  cluster_identifier      = "test-db"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.03.0"
  database_name          = "testdb"
  master_username        = "admin"
  master_password        = "password1234"
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.test-db-sg.id]
  db_subnet_group_name   = aws_db_subnet_group.test-subnet-group.name
}

resource "aws_db_subnet_group" "test-subnet-group" {
  name       = "test-db-subnet-group"
  subnet_ids = [aws_subnet.test-subnet-1.id, aws_subnet.test-subnet-2.id]
}

# SQS(FIFO 큐) 생성
resource "aws_sqs_queue" "test-sqs" {
  name                        = "test-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

# EC2 인스턴스 생성 (test-web)
resource "aws_instance" "test-web" {
  ami             = "ami-0d72e8d1c4eee2059"
  instance_type   = "t2.micro"
  key_name        = "soldesk_Key"
  security_groups = [aws_security_group.test-web-sg.name]
  subnet_id       = aws_subnet.test-subnet-1.id

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras enable nginx1
    sudo yum install -y nginx java-17-amazon-corretto
    sudo systemctl enable nginx
    sudo systemctl start nginx

    # 환경 변수 설정 (Spring Boot에서 RDS 및 SQS 사용 가능)
    echo "export DB_URL='jdbc:mysql://${aws_rds_cluster.test-db.endpoint}:3306/testdb'" >> /etc/environment
    echo "export DB_USER='admin'" >> /etc/environment
    echo "export DB_PASS='password1234'" >> /etc/environment
    echo "export SQS_QUEUE_URL='${aws_sqs_queue.test-sqs.id}'" >> /etc/environment
    source /etc/environment

    sudo systemctl restart nginx
  EOF

  tags = {
    Name = "test-web"
  }
}

# 보안 그룹 설정 (EC2)
resource "aws_security_group" "test-web-sg" {
  name   = "test-web-sg"
  vpc_id = aws_vpc.test-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# 보안 그룹 설정 (Aurora DB)
resource "aws_security_group" "test-db-sg" {
  name   = "test-db-sg"
  vpc_id = aws_vpc.test-vpc.id

  # EC2에서 Aurora DB(MySQL)로 접속 허용 (3306 포트)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.test-web-sg.id] # EC2에서만 접근 가능
  }

  # Aurora DB가 외부와 통신할 수 있도록 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
