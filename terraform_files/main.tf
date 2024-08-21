resource "aws_security_group" "my_security_group1" {
  name        = "my-security-group1"
  description = "Allow SSH, HTTP, HTTPS, 8080 for Jenkins & Maven"

  # SSH Inbound Rules
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Outbound Rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "my_ec2_instance1" {
  ami                    = "ami-0492447090ced6eb5"
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.my_security_group1.id]
  key_name               = "Terraform-Key"

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }
  tags = {
    Name = "MASTER-SERVER"
  }
  user_data = <<-EOF
    #!/bin/bash
    # wait for 1min before EC2 initialization
    sleep 60
    sudo wget https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
    sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
    sudo yum install -y apache-maven
    sudo yum install java-1.8.0-devel -y
  EOF

  # STEP3: USING REMOTE-EXEC PROVISIONER TO INSTALL TOOLS
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./Terraform-Key.pem") # replace with your key-name 
      user        = "ec2-user"
      host        = self.public_ip
    }

    inline = [
      # wait for 200sec before EC2 initialization
      "sleep 200",
      # Install Git 
      "sudo yum install git -y",

      # Install Jenkins 
      # REF: https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/
      "sudo yum update –y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
      "sudo yum upgrade -y",
      "sudo yum install java-17-amazon-corretto -y",
      "sudo yum install jenkins -y",
      "sudo systemctl enable jenkins",
      "sudo systemctl start jenkins",
      "sudo systemctl status jenkins",


      # Install Docker
      # REF: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html
      "sudo yum update -y",
      "sudo yum install docker -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker jenkins",
      # To avoid below permission error
      # Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
      "sudo chmod 666 /var/run/docker.sock",

      # Install Trivy
      # REF: https://aquasecurity.github.io/trivy/v0.18.3/installation/
      "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm",

      # Install Ansible
      "sudo yum update -y",
      "sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y",
      "sudo yum install git python python-devel python-pip openssl ansible -y",
    ]
  }
}

# STEP3: OUTPUT PUBLIC IP OF EC2 INSTANCE
output "ACCESS_YOUR_JENKINS_HERE" {
  value = "http://${aws_instance.my_ec2_instance1.public_ip}:8080"
}

output "Jenkins_Initial_Password" {
  value = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

# STEP4: OUTPUT PUBLIC IP OF EC2 INSTANCE
output "MASTER_SERVER_PUBLIC_IP" {
  value = aws_instance.my_ec2_instance1.public_ip
}

# STEP5: OUTPUT PRIVATE IP OF EC2 INSTANCE
output "MASTER_SERVER_PRIVATE_IP" {
  value = aws_instance.my_ec2_instance1.private_ip
}