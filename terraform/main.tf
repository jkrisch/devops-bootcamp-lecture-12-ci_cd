terraform{
    required_version = ">= 0.12"
    backend "s3" {
        bucket = "myapp-tf-s3-bucket-jk"
        key = "myapp/state.tfstate"
        region "eu-central-1"
    }
    
}

provider "aws" {
    #We can set the region in the provider
    region="eu-central-1"
}



resource "aws_vpc" "myapp_vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}


resource "aws_subnet" "myapp_subnet-1" {
    vpc_id = aws_vpc.myapp_vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-internet_gateway-1"{
    vpc_id = aws_vpc.myapp_vpc.id

    tags = {
        Name: "${var.env_prefix}-igw"
    }
}

#Instead of creating a new route table we could also have used the default one:
resource "aws_default_route_table" "main-rtb"{
    default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-internet_gateway-1.id
    }
    tags = {
        Name: "${var.env_prefix}-rtb"
    }
}


resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp_vpc.id

    #incoming (ingress) traffic rules
    ingress {
        #we could define a range - therefore it is from_ and to_
        from_port = 22
        to_port = 22

        protocol = "TCP"

        #List of IP addresses which can access the EC2 instance on specific port (22 in this case)
        cidr_blocks = [var.my_ip]
    }

    ingress {
        #we could define a range - therefore it is from_ and to_
        from_port = 8080
        to_port = 8080

        protocol = "TCP"

        #here we let any ip address through
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

        #allowing access to vpc endpoints
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    #with most_recent you define that you always want to use the latest version
    most_recent = true

    #via owners you can filter for images from specific image creators (maybe your own)
    owners = ["amazon"]

    #using filter, you can also select images using specific search criteria
    #you can use multiple filter to narrow down your selection
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-*-x86_64-gp2"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}


#create an EC2 instance
resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.image_id

    #size of your machine like - t2.micro, t2.small, t2.large, etc.
    instance_type = var.instance_type



    subnet_id = aws_subnet.myapp_subnet-1.id    

    #we can configure multiple security groups for our ec2 instance
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]

    availability_zone = var.avail_zone

    #to be able to access it via browser we need the ec2 instance to get a public ip
    associate_public_ip_address = true

    key_name = "myapp-key-pair-jenkins"

    user_data = file("entrypoint.sh")
    user_data_replace_on_change = true

    tags = {
        Name: "${var.env_prefix}-server"
    }
}


#using output we verify or check the data selection
output "ec2_instance_public_ip"{
    value = aws_instance.myapp-server.public_ip
}