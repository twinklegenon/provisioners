provider "aws" {
  region     = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}


resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "example"
  }
}

resource "aws_route_table_association" "associate" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.example.id
}


resource "aws_security_group" "allow_traffic" {
  name        = "allow_traffic"
  description = "Allow traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow traffic"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.allow_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"  # Allows all outbound traffic
}


resource "aws_eip" "lb" {
  domain = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.myec2.id
  allocation_id = aws_eip.lb.id
  depends_on    = [aws_instance.myec2]
}

resource "aws_instance" "myec2" {
  ami                         = "ami-085ad6ae776d8f09c"
  instance_type               = "t2.micro"
  key_name                    = "KeyPair-Twinkle1"
  vpc_security_group_ids      = [aws_security_group.allow_traffic.id]
  subnet_id                   = aws_subnet.main.id
  associate_public_ip_address = true


  connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/KeyPair-Twinkle1.pem")
      host        = self.public_ip
    }
    
  provisioner "remote-exec" {
    inline = [
    "sudo amazon-linux-extras enable nginx1",
    "sudo yum clean metadata",
    "sudo yum -y install nginx",
    "sudo systemctl start nginx",
    "sudo systemctl enable nginx",
    "touch /home/ec2-user/tuts-remote-exec.txt"
    ]
  }

  provisioner "local-exec" {
		command = "echo ${aws_eip.lb.public_ip} > instance-ip.txt"
	}

  depends_on = [aws_internet_gateway.igw]
}