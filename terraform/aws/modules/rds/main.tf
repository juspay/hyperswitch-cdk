resource "aws_db_subnet_group" "aurora" {
  name       = "${var.stack_name}-aurora-subnet-group"
  subnet_ids = var.subnet_ids["database_zone"]

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-aurora-subnet-group"

  })
}

resource "aws_rds_cluster" "aurora" {

  cluster_identifier = "${var.stack_name}-db-cluster"
  engine             = "aurora-postgresql"
  engine_version     = "14.15"
  engine_mode        = "provisioned"

  database_name   = var.db_name
  master_username = var.db_user
  master_password = var.db_password
  port            = var.db_port

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.aurora.name

  storage_encrypted = true

  skip_final_snapshot = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-db-cluster"
  })
}

# Aurora Writer Instance
resource "aws_rds_cluster_instance" "writer" {

  identifier                 = "${var.stack_name}-writer-instance"
  cluster_identifier         = aws_rds_cluster.aurora.id
  instance_class             = "db.t3.medium"
  engine                     = aws_rds_cluster.aurora.engine
  engine_version             = aws_rds_cluster.aurora.engine_version
  publicly_accessible        = false
  auto_minor_version_upgrade = false

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-writer-instance"
    Role = "writer"
  })
}

# Aurora Reader Instance
resource "aws_rds_cluster_instance" "reader" {

  identifier                 = "${var.stack_name}-reader-instance"
  cluster_identifier         = aws_rds_cluster.aurora.id
  instance_class             = "db.t3.medium"
  engine                     = aws_rds_cluster.aurora.engine
  engine_version             = aws_rds_cluster.aurora.engine_version
  auto_minor_version_upgrade = false

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-reader-instance"
    Role = "reader"
  })
}
