
# output
# state bucket
# {}, 

data "terraform_remote_state" "operation_environment_networking" {
  backend = "s3"

  config = {
    region = "us-east-1"
    bucket = "kojitechs-deploy-vpcchildmodule.tf-12"
    key    = format("env:/%s/path/env", terraform.workspace)
  }
}


locals {
  operational_env  = data.terraform_remote_state.operation_environment_networking.outputs
  vpc_id           = local.operational_env.vpc_id
  pub_subnet       = local.operational_env.public_subnet
  pri_subnet       = local.operational_env.private_subnet
  database_subnet  = local.operational_env.database_subnet
  instance_profile = aws_iam_instance_profile.instance_profile.name
  name             = "kojitechs-${replace(basename(var.component_name), "-", "-")}"
}

# sas, r, spss
# 
### APP1(frontend)
# apache (index.html) # . app1, app2 (install using userdata)
resource "aws_instance" "front_endapp1" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t2.micro"
  subnet_id              = local.pri_subnet[0]
  vpc_security_group_ids = [aws_security_group.front_app_sg.id]
  user_data              = file("${path.module}/template/frontend_app1.sh")
  iam_instance_profile   = local.instance_profile

  tags = {
    Name = "front_endapp1"
  }
}
# https://domain_name/
#### App2(frontend)
resource "aws_instance" "front_endapp2" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t2.micro"
  subnet_id              = local.pri_subnet[1]
  vpc_security_group_ids = [aws_security_group.front_app_sg.id]
  user_data              = file("${path.module}/template/frontend_app2.sh")
  iam_instance_profile   = local.instance_profile

  tags = {
    Name = "front_endapp2"
  }
}

#### registration app (2)
# we have two instances her
# aws_instance.registration_app[0].id 
# 
resource "aws_instance" "registration_app" {
  depends_on = [module.aurora]
  count      = length(var.name)

  ami                    = data.aws_ami.ami.id
  instance_type          = terraform.workspace == "prod" ? "t2.xlarge" : "t2.large"
  subnet_id              = element(local.pri_subnet, count.index)
  iam_instance_profile   = local.instance_profile
  vpc_security_group_ids = [aws_security_group.registration_app.id]
  user_data = templatefile("${path.root}/template/registration_app.tmpl",
    {
      endpoint    = module.aurora.cluster_endpoint
      port        = module.aurora.cluster_port
      db_name     = module.aurora.cluster_database_name
      db_user     = module.aurora.cluster_master_username
      db_password = module.aurora.cluster_master_password
    }
  )
  tags = {
    Name = var.name[count.index]
  }
}


### mysql Aurora database (15m) 
