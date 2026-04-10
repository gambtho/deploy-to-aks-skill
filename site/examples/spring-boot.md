# Spring Boot Example

**Scenario:** Java Spring Boot web application with PostgreSQL database, deployed to AKS Automatic.

**Generated for:** `sample-spring-boot-app` (fictional project)

---

## Dockerfile

Multi-stage build with Maven, non-root user, JRE 21:

```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Key features:**
- Multi-stage build reduces image size (build tools not in final image)
- Non-root user for security (AKS Deployment Safeguard DS012)
- Dependency caching for faster rebuilds
- Alpine-based JRE for minimal footprint

---

## Kubernetes Manifests

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-spring-boot-app
  namespace: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-spring-boot-app
  template:
    metadata:
      labels:
        app: sample-spring-boot-app
    spec:
      serviceAccountName: sample-spring-boot-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: <acr-name>.azurecr.io/sample-spring-boot-app:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATASOURCE_URL
          value: jdbc:postgresql://sample-app-postgres.postgres.database.azure.com:5432/appdb
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-spring-boot-app
  namespace: sample-app
spec:
  type: ClusterIP
  selector:
    app: sample-spring-boot-app
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

### Gateway API (AKS Automatic)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: sample-spring-boot-app-gateway
  namespace: sample-app
  annotations:
    gateway.networking.k8s.io/v1: "true"
spec:
  gatewayClassName: azure-alb
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sample-spring-boot-app-route
  namespace: sample-app
spec:
  parentRefs:
  - name: sample-spring-boot-app-gateway
  rules:
  - backendRefs:
    - name: sample-spring-boot-app
      port: 80
```

---

## Bicep Infrastructure

### Main Module

```bicep
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param appName string = 'sample-spring-boot-app'
param environment string = 'dev'

module aks 'aks.bicep' = {
  name: 'aks-deployment'
  params: {
    location: location
    clusterName: '${appName}-${environment}-aks'
    nodeCount: 2
  }
}

module acr 'acr.bicep' = {
  name: 'acr-deployment'
  params: {
    location: location
    registryName: replace('${appName}${environment}acr', '-', '')
  }
}

module postgres 'postgres.bicep' = {
  name: 'postgres-deployment'
  params: {
    location: location
    serverName: '${appName}-${environment}-postgres'
    administratorLogin: 'sqladmin'
    databaseName: 'appdb'
  }
}

module identity 'identity.bicep' = {
  name: 'identity-deployment'
  params: {
    location: location
    identityName: '${appName}-${environment}-identity'
    aksOidcIssuer: aks.outputs.oidcIssuer
    namespace: 'sample-app'
    serviceAccountName: appName
  }
}

output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
output postgresServerName string = postgres.outputs.serverName
```

---

## GitHub Actions Workflow

```yaml
name: Deploy to AKS

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  ACR_NAME: samplespringbootappdevacr
  IMAGE_NAME: sample-spring-boot-app
  AKS_CLUSTER: sample-spring-boot-app-dev-aks
  AKS_RESOURCE_GROUP: sample-app-rg
  NAMESPACE: sample-app

permissions:
  id-token: write
  contents: read

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        distribution: 'temurin'
        java-version: '21'
        cache: 'maven'
    
    - name: Build with Maven
      run: mvn clean package -DskipTests
    
    - name: Azure Login (OIDC)
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Build and push Docker image
      run: |
        az acr build --registry ${{ env.ACR_NAME }} \
          --image ${{ env.IMAGE_NAME }}:${{ github.sha }} \
          --image ${{ env.IMAGE_NAME }}:latest \
          --file Dockerfile .
    
    - name: Get AKS credentials
      run: |
        az aks get-credentials \
          --resource-group ${{ env.AKS_RESOURCE_GROUP }} \
          --name ${{ env.AKS_CLUSTER }}
    
    - name: Deploy to AKS
      run: |
        kubectl set image deployment/${{ env.IMAGE_NAME }} \
          app=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          -n ${{ env.NAMESPACE }}
        kubectl rollout status deployment/${{ env.IMAGE_NAME }} -n ${{ env.NAMESPACE }}
```

**Key features:**
- OIDC authentication (no stored secrets)
- Maven caching for faster builds
- ACR build (no local Docker daemon needed)
- Automatic rollout verification

---

## Safeguards Compliance

All manifests pass AKS Deployment Safeguards:

- ✅ **DS001** - Container image provenance (ACR registry)
- ✅ **DS002** - Resource requests defined (250m CPU, 512Mi memory)
- ✅ **DS003** - Resource limits defined (1000m CPU, 1Gi memory)
- ✅ **DS004** - Liveness probe configured
- ✅ **DS005** - Readiness probe configured
- ✅ **DS006** - Security context set (runAsNonRoot, seccomp)
- ✅ **DS012** - Non-root user (UID 1000)
- ✅ **DS013** - Capabilities dropped (ALL)

[Learn more about Deployment Safeguards](/guide/safeguards)
