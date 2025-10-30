# diagram.py
from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.vcs import Github
from diagrams.onprem.client import Users
from diagrams.aws.compute import ECS, ECR
from diagrams.aws.network import ELB

with Diagram("Web Service", show=False, direction="TB", filename="arch_diagram"):
    user = Users("User")
    github = Github("GitHub\nBuild & publish Docker images via CI/CD pipeline", fontsize="10")

    with Cluster("AWS Cloud"):
        ecr = ECR("Container Registry")

        with Cluster("Service Cluster"):
            lb = ELB("Load Balancer")
            proxy = ECS("Proxy service\n(NGINX with API key validation and rate limiting)", fontsize="10")
            api = ECS("API service - Simple Go web app")
            service = [proxy, api]
    # Define connections outside of cluster contexts
    github >> Edge(label="Push code", style="bold", fontsize="10") >> ecr
    ecr << Edge(label="Pull images", color="green", fontsize="10") << service
    user >> Edge(label="Send requests", color="firebrick", fontsize="10") >> lb
    lb >> Edge(label="Route traffic", fontsize="10") >> proxy
    proxy >> Edge(label="Forward requests", fontsize="10") >> api