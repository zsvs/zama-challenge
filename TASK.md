# Task Documentation

This document contains screenshots and visualizations of the deployed infrastructure and monitoring setup.

## Script for checking

```bash
#!/bin/bash

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Making request to zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com"

    curl -H 'X-Api-Key: TXlfc3VwZXJfRHVwZXJfTWVHYV9TZUNyRXRfS2VZ' -H 'Content-Type: application/json'   -d '{"a": 5, "b": 40}'  zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com/sum
    curl http://zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com/readyz
    curl http://zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com/healthz

    echo ""
    echo "---"
done
```

Answer example:

```log
---
[2025-10-31 14:03:56] Making request to zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com
{"sum":45}
ready{"status":"ok","uptime_seconds":1046.4}
---
[2025-10-31 14:03:57] Making request to zama-challenge-alb-1455990262.eu-west-1.elb.amazonaws.com
{"sum":45}
ready{"status":"ok","uptime_seconds":1046.9}
---
```

---

## Load Balancer

![Load Balancer](./img/LoadBalancer.png)

*Application Load Balancer (ALB) configuration showing listeners, availability zones, security groups, and DNS name for routing traffic to ECS tasks.*

---

## ALB Target Group

![ALB Target Group](./img/ALB-TG.png)

*ALB Target Group configuration displaying registered targets, health check settings, and target health status for the ECS service.*

---

## CloudWatch Alarm

![CloudWatch Alarm](./img/CloudWatch-Alarm.png)

*CloudWatch alarm configuration for monitoring ALB 5xx errors and triggering notifications when thresholds are exceeded.*

---

## CloudWatch Dashboard

![CloudWatch Dashboard](./img/CloudWatch-Dashboard.png)

*CloudWatch dashboard displaying key metrics including ALB performance, ECS CPU utilization, and service health indicators.*

---

## E1S Dashboard

![E1S Dashboard](./img/E1S-dashboard.png)

*E1S dashboard overview showing system-level metrics and performance indicators.*

---

## ECR Image

![ECR Image](./img/ECR-Img.png)

*Container image stored in Amazon Elastic Container Registry (ECR) with tags and vulnerability scan results.*

---

## ECR Registry

![ECR Registry](./img/ECR-Reg.png)

*Amazon ECR registry showing all container repositories for the zama-api and zama-nginx services.*

---

## ECS Dashboard

![ECS Dashboard](./img/ECS-Dashboard.png)

*Amazon ECS dashboard displaying cluster information, running tasks, and service status.*

---

## ECS Service

![ECS Service](./img/ECS-Service.png)

*ECS service configuration showing desired count, running tasks, deployment status, and load balancer integration.*

---

## ECS Task

![ECS Task](./img/ECS-Task.png)

*ECS task definition details including container configurations, environment variables, resource allocations, and networking settings.*
