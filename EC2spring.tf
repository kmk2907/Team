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

    # Spring Boot 애플리케이션 다운로드 및 실행
    sudo mkdir -p /opt/app
    cd /opt/app
    sudo aws s3 cp s3://my-spring-boot-bucket/myapp.jar myapp.jar  # S3에서 JAR 다운로드 (필요 시 수정)
    sudo chmod +x myapp.jar

    # Spring Boot 애플리케이션 실행 (백그라운드 모드)
    nohup java -jar myapp.jar > /var/log/myapp.log 2>&1 &

    # 서비스 등록 (자동 실행)
    echo "[Unit]
    Description=Spring Boot Application
    After=network.target

    [Service]
    User=root
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/java -jar /opt/app/myapp.jar
    SuccessExitStatus=143
    Restart=always
    RestartSec=5
    StandardOutput=syslog
    StandardError=syslog
    SyslogIdentifier=spring-boot-app

    [Install]
    WantedBy=multi-user.target" | sudo tee /etc/systemd/system/spring-boot.service

    sudo systemctl daemon-reload
    sudo systemctl enable spring-boot
    sudo systemctl start spring-boot
  EOF

  tags = {
    Name = "test-web"
  }
}
