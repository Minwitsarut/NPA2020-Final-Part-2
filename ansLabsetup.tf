##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "us-east-1"
}
variable "network_61070210" {
  default = "10.1.0.0/16"
}
variable "Public-61070210-1" {
  default = "10.1.0.0/24"
}
variable "Public-61070210-2" {
    default = "10.1.1.0/24"
}



##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##################################################################################
# RESOURCES
##################################################################################


# NETWORKING #
resource "aws_vpc" "NPA21-61070210" {
    cidr_block = var.network_61070210
    enable_dns_hostnames = true

    tags ={
        Name = "NPA21-61070210"
    }
}

resource "aws_internet_gateway" "NPA21-61070210-igateway" {
    vpc_id = aws_vpc.NPA21-61070210.id

    tags ={
        Name = "NPA21-61070210-igateway"
    }
}

resource "aws_subnet" "Public1" {
    vpc_id = aws_vpc.NPA21-61070210.id
    cidr_block = var.Public-61070210-1
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true
    tags ={
        Name = "Public-61070210-1"
    }
}

resource "aws_subnet" "Public2" {
    vpc_id = aws_vpc.NPA21-61070210.id
    cidr_block = var.Public-61070210-2
    map_public_ip_on_launch = true
    availability_zone = data.aws_availability_zones.available.names[1]

    tags ={
        Name = "Public-61070210-2"
    }
}

# ROUTING #
resource "aws_route_table" "NPA21-61070210-publicRoute" {
    vpc_id = aws_vpc.NPA21-61070210.id
        route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.NPA21-61070210-igateway.id
        }
    tags ={
        Name = "NPA21-61070210-publicRoute"
    }
}

resource "aws_route_table_association" "NPA21-61070210-rt-pubsub1" {
  subnet_id = aws_subnet.Public1.id
  route_table_id = aws_route_table.NPA21-61070210-publicRoute.id
}

resource "aws_route_table_association" "NPA21-61070210-rt-pubsub2" {
  subnet_id = aws_subnet.Public2.id
  route_table_id = aws_route_table.NPA21-61070210-publicRoute.id

}
# SECURITY GROUPS #
# ssh security group 
resource "aws_security_group" "ssh-sg" {
  name   = "ssh_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from anywhere
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags ={
      Name = "sshrule"
  }
}


# INSTANCES #
resource "aws_instance" "ansible" {
  ami                    = data.aws_ami.aws-linux-2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.ssh-sg.id]
  key_name               = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }


  provisioner "remote-exec" {
    inline = [
        "sudo yum update -y",
        "sudo amazon-linux-extras install ansible2 -y",
        "ls -a",
        "ls -a"

    ]
  }

  tags ={
      Name = "ansibleNode"
  }

}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.aws-linux-2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.ssh-sg.id]
  key_name               = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }

  provisioner "remote-exec" {
    inline = [
        "sudo yum update -y",
        "ls -a"

    ]
  }

  tags ={
      Name = "web"
  }

}
resource "aws_instance" "db1" {
  ami                    = data.aws_ami.aws-linux-2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.ssh-sg.id]
  key_name               = var.key_name

    connection {
        type        = "ssh"
        host        = self.public_ip
        user        = "ec2-user"
        private_key = file(var.private_key_path)

    }


  provisioner "remote-exec" {
    inline = [
        "sudo yum update -y",
        "ls -a"

    ]
  }

  tags ={
      Name = "db1"
  }
}

  ##################################################################################
  # OUTPUT
  ##################################################################################

output "aws_instance_private_ip_web" {
value = aws_instance.web.private_ip
}

output "aws_instance_public_ip_web" {
value = "ssh -i vockey.pem ec2-user@${aws_instance.web.public_ip}"
}

output "aws_instance_private_ip_db1" {
value = aws_instance.db1.private_ip
}
output "aws_instance_public_ip_db1" {
value = "ssh -i vockey.pem ec2-user@${aws_instance.db1.public_ip}"
}

output "aws_instance_public_ip_ansibleNode" {
value = "ssh -i vockey.pem ec2-user@${aws_instance.web.public_ip}"
}