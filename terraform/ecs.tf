# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "node-devops-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "node_app" {
  family                   = "node-app"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name      = "node-app"
      image     = "taiwob1/node-devops-app:latest"
      essential = true
      portMappings = [{
        containerPort = 3000
        hostPort      = 3000
      }]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "node_service" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.node_app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets         = [aws_subnet.public.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.node_tg.arn
    container_name   = "node-app"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.node_listener]
}