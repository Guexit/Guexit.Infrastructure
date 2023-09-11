# Azure Container Apps

Azure Container Apps is a fully managed environment that enables you to run containerized applications. It's commonly used to deploy and run microservices.

## Purpose

Deploy images of our .NET services in a auto-managed infrastructure, enabling us to use a Continuous Deployment pipeline in GitHub Actions that automates promotion of new versions. This Azure resource leaves behind concerns of managing cloud infrastructure. Just by having the Container Apps environment in our Infrastructure as code, we'll be able to run services within the environment VN, having public ingress routes, etc. 

## Key features

1. Run docker images from any registry (GitHub container registry included).
2. Granularly expose HTTPS or TCP traffic to outside of the virtual network.
3. Automate deployment using a CD pipeline in GitHub.
4. Upgrade service versions with Zero Downtime.
5. Manage environment variables and secrets.
6. Scale horizontally and vertically automatically.
7. Internal service discovery.
8. Logging and monitoring out of the box.

## Configuration Details

- Region (possibility of multi-region)
- Resource group
- Dependencies
- Resources, capacity, memory, vCPU, etc

## Backup and Disaster Recovery

- It create an spapshot with every deployment, this gives us the possiblity of automatically recover the system to an specific state.

## Official documentation

- https://learn.microsoft.com/en-us/azure/container-apps
- https://www.youtube.com/watch?v=b3dopSTnSRg