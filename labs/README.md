# Getting started with use cases

1. Clone this repository

```code
git clone https://github.com/f5devcentral/NGINX-Ingress-Controller-Lab.git
```

2. Change directory

```code
cd NGINX-Ingress-Controller-Lab/labs
```

## Running use cases

- [Lab 1](1.basic-ingress) - Basic Ingress Controller, URI-based routing and TLS offload
- [Lab 2](2.advanced-routing) - Advanced L7 routing
- [Lab 3](3.authentication) - JWT authentication
- [Lab 4](4.traffic-splitting) - Traffic splitting
- [Lab 5](5.access-control) - Access control
- [Lab 6](6.rate-limiting) - Rate limiting
- [Lab 7](7.waf) - F5 WAF for NGINX (Requires NGINX Ingress Controller deployment [without precompiled WAF policies](/DEPLOYING.md))
- [Lab 8](8.waf-precompiled) - F5 WAF for NGINX using precompiled policies (Requires NGINX Ingress Controller deployment [with precompiled WAF policies](/DEPLOYING-WAFv5.md))
- [Lab 9](9.waf-plm) - F5 WAF for NGINX using [Policy Lifecycle Manager](https://docs.nginx.com/nginx-ingress-controller/install/plm-installation/)

The official NGINX Ingress Controller repository provides additional [examples](https://github.com/nginx/kubernetes-ingress/tree/main/examples)
