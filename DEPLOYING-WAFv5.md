# Lab deployment

See the [prerequisites](/README.md#getting-started)

This deployment is for NGINX Ingress Controller and F5 WAF for NGINX with precompiled WAF policies and log profiles

## Installing

1. Create NGINX Ingress Controller namespace

```code
kubectl create namespace nginx-ingress
```

2. Create Kubernetes secret to pull images from NGINX private registry

```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

3. Create Kubernetes secret holding the NGINX Plus license

```code
kubectl create secret generic license-token --from-file=license.jwt=<nginx-one-eval.jwt> --type=nginx.com/license -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. List available NGINX Ingress Controller docker images that include NGINX App Protect WAF

```code
curl -s https://private-registry.nginx.com/v2/nginx-ic-nap-v5/nginx-plus-ingress/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`5.5.0` at the time of writing)

5. Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)
```code
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.0/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.0/deploy/crds-nap-waf.yaml
```

6. Create the PVCs to store compiled WAF policy bundles and logging profiles
```code
kubectl apply -f ./deployment/pvcs.yaml
```

7. Install NGINX Ingress Controller with NGINX App Protect through its Helm chart (set `nginx.image.tag` to the latest `5.x` available NGINX Ingress Controller version and adjust the chart version accordingly)

```code
helm install nic oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.6.0 \
  --set controller.image.repository=private-registry.nginx.com/nginx-ic-nap-v5/nginx-plus-ingress \
  --set controller.image.tag=5.5.0 \
  --set controller.nginxplus=true \
  --set controller.appprotect.enable=true \
  --set controller.appprotect.v5=true \
  --set-json 'controller.appprotect.volumes=[{"name":"app-protect-bd-config","emptyDir":{}},{"name":"app-protect-config","emptyDir":{}},{"name":"app-protect-bundles","persistentVolumeClaim":{"claimName":"task-pv-claim"}}]' \
  --set controller.volumeMounts[0].name=app-protect-bundles \
  --set controller.volumeMounts[0].mountPath="/etc/app_protect/bundles/" \
  --set controller.serviceAccount.imagePullSecretName=regcred \
  --set controller.mgmt.licenseTokenSecretName=license-token \
  --set controller.service.type=NodePort \
  -n nginx-ingress
```

8. Check NGINX Ingress Controller pod status

```code
kubectl get pods -n nginx-ingress
```

Pod should be in the `Running` state

```code
NAME                                           READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-8b75b59bf-5zcc2   3/3     Running   0          3m28s
```

9. Check NGINX Ingress Controller logs

```code
kubectl logs -l app.kubernetes.io/instance=nic -n nginx-ingress -c nginx-ingress
```

Output should be similar to

```code
2026/06/03 12:59:15 [notice] 21#21: exit
2026/06/03 12:59:15 [notice] 20#20: exit
I20260603 12:59:15.483509   1 main.go:110] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress", UID:"c831b246-2605-46f9-9239-e95d83fecc8a", APIVersion:"v1", ResourceVersion:"120951043", FieldPath:""}): type: 'Normal' reason: 'Updated' ConfigMap nginx-ingress/nic-nginx-ingress updated without error
I20260603 12:59:15.483544   1 main.go:110] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-mgmt", UID:"b27d78ca-b4aa-4950-8740-8024deb3fd7b", APIVersion:"v1", ResourceVersion:"120951041", FieldPath:""}): type: 'Normal' reason: 'Updated' MGMT ConfigMap nginx-ingress/nic-nginx-ingress-mgmt updated without error
2026/06/03 12:59:15 [notice] 14#14: signal 17 (SIGCHLD) received from 21
2026/06/03 12:59:15 [notice] 14#14: worker process 21 exited with code 0
2026/06/03 12:59:15 [notice] 14#14: signal 29 (SIGIO) received
2026/06/03 12:59:15 [notice] 14#14: signal 17 (SIGCHLD) received from 20
2026/06/03 12:59:15 [notice] 14#14: worker process 20 exited with code 0
2026/06/03 12:59:15 [notice] 14#14: signal 29 (SIGIO) received
```

10. Check Kubernetes service status

```code
kubectl get svc -n nginx-ingress
```

NGINX Ingress Controller should be listening on TCP ports 80 and 443

```code
NAME                           TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
nic-nginx-ingress-controller   NodePort   10.111.219.126   <none>        80:30106/TCP,443:31131/TCP   4m25s
```

10. Check the `ingressclass`

```code
kubectl get ingressclass
```

The `nginx` ingressclass should be available

```code
NAME    CONTROLLER                     PARAMETERS   AGE
nginx   nginx.org/ingress-controller   <none>       4m45s
```

## Build the WAF compiler

1. Clone this repository and `cd` into it
```code
git clone https://github.com/f5devcentral/NGINX-Ingress-Controller-Lab.git
cd NGINX-Ingress-Controller-Lab
```

2. List available F5 WAF for NGINX compiler versions
```code
curl -s https://private-registry.nginx.com/v2/nap/waf-compiler/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

3. Set up Docker to authenticate to the private registry
```code
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp <nginx-one-eval.crt> /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp <nginx-one-eval.key> /etc/docker/certs.d/private-registry.nginx.com/client.key
```

4. Build the F5 WAF for NGINX compiler (`5.13.1` at the time of writing):
```code
docker build -f deployment/Dockerfile --no-cache --platform linux/amd64 \
  --secret id=nginx-crt,src=<nginx-one-eval.crt> \
  --secret id=nginx-key,src=<nginx-one-eval.key> \
  -t waf-compiler-5.13.1:custom .
```

5. The output should be similar to
```code
[+] Building 100.6s (8/8) FINISHED                                                                                                                                                                                             docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                                                                     0.1s
 => => transferring dockerfile: 1.36kB                                                                                                                                                                                                   0.0s
 => resolve image config for docker-image://docker.io/docker/dockerfile:1                                                                                                                                                                1.3s
 => docker-image://docker.io/docker/dockerfile:1@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89                                                                                                                 2.3s
 => => resolve docker.io/docker/dockerfile:1@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89                                                                                                                     0.1s
 => => sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89 9.08kB / 9.08kB                                                                                                                                           0.0s
 => => sha256:e82bbc85c3cb06cf2a5a27b058208b43984448acbcd6a832cd1491933d4376dd 1.13kB / 1.13kB                                                                                                                                           0.0s
 => => sha256:1a998cca4d41cfecafb1989342c5e7378bc992589af7d47510c4b854bebfc7d7 1.33kB / 1.33kB                                                                                                                                           0.0s
 => => sha256:50ba52cd6a2c01eaf1a9efbedc7c75b5da5e3965c1586001c722980487a73fd7 14.36MB / 14.36MB                                                                                                                                         1.9s
 => => extracting sha256:50ba52cd6a2c01eaf1a9efbedc7c75b5da5e3965c1586001c722980487a73fd7                                                                                                                                                0.2s
 => [internal] load metadata for private-registry.nginx.com/nap/waf-compiler:5.11.2                                                                                                                                                      0.4s
 => [internal] load .dockerignore                                                                                                                                                                                                        0.1s
 => => transferring context: 2B                                                                                                                                                                                                          0.0s
 => [stage-0 1/2] FROM private-registry.nginx.com/nap/waf-compiler:5.11.2@sha256:3b3c2359a3a5f2f6a7256a1a7eea4405b21d29f13242f61e6fd36152ac35a91a                                                                                       28.4s
 => => resolve private-registry.nginx.com/nap/waf-compiler:5.11.2@sha256:3b3c2359a3a5f2f6a7256a1a7eea4405b21d29f13242f61e6fd36152ac35a91a                                                                                                0.0s
 => => sha256:9773f5f166286aa5b8bb320d1a8a9dfd7429c6e2aeb4fdd9cd76d23b71a7d41f 5.38kB / 5.38kB                                                                                                                                           0.0s
 => => sha256:5d1190f163bbd0ad6f230b79d7d863f4986fd202d7159d725d0d0a827f2caaa3 30.45MB / 30.45MB                                                                                                                                         8.9s
 => => sha256:3ec4cd663f6807835bd0ebfb29534ae4b94d5d0877f3efca43fb8d88be87fa42 58.16MB / 58.16MB                                                                                                                                        14.7s
 => => sha256:dde3167cf6ffa735b7b66f768e3edc684010786fb3c256b98adb3ec4035fe86f 639B / 639B                                                                                                                                               0.1s
 => => sha256:3b3c2359a3a5f2f6a7256a1a7eea4405b21d29f13242f61e6fd36152ac35a91a 1.58kB / 1.58kB                                                                                                                                           0.0s
 => => sha256:ad88868502f61d41a728c42f7e294a0ac553b8351539cdd762e66f1301f915bc 3.07MB / 3.07MB                                                                                                                                           1.5s
 => => sha256:224e03e3b84cccf84897b3e33aded9930fb85c2470a8f71a54d1b931beb9d64b 18.70MB / 18.70MB                                                                                                                                         7.5s
 => => sha256:02afb1ff007e208c2b03b1b6652cef7fda1eb26c429b6ddf10ce7666beaa2b5f 102.80MB / 102.80MB                                                                                                                                      24.0s
 => => extracting sha256:5d1190f163bbd0ad6f230b79d7d863f4986fd202d7159d725d0d0a827f2caaa3                                                                                                                                                1.2s
 => => extracting sha256:3ec4cd663f6807835bd0ebfb29534ae4b94d5d0877f3efca43fb8d88be87fa42                                                                                                                                                1.3s
 => => extracting sha256:dde3167cf6ffa735b7b66f768e3edc684010786fb3c256b98adb3ec4035fe86f                                                                                                                                                0.0s
 => => extracting sha256:ad88868502f61d41a728c42f7e294a0ac553b8351539cdd762e66f1301f915bc                                                                                                                                                0.0s
 => => extracting sha256:224e03e3b84cccf84897b3e33aded9930fb85c2470a8f71a54d1b931beb9d64b                                                                                                                                                0.1s
 => => extracting sha256:02afb1ff007e208c2b03b1b6652cef7fda1eb26c429b6ddf10ce7666beaa2b5f                                                                                                                                                3.7s
 => [stage-0 2/2] RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644     --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644     apt-get update     && apt-get install -y        65.7s
 => exporting to image                                                                                                                                                                                                                   0.5s
 => => exporting layers                                                                                                                                                                                                                  0.3s
 => => writing image sha256:76f6a08988cd7896e92ec6975a89257204ddd1304936fbcf949d508d68d3f26c                                                                                                                                             0.0s
 => => naming to docker.io/library/waf-compiler-5.13.1:custom                                                                                                                                                                            0.1s
```

## Uninstalling

1. Uninstall NGINX Ingress Controller through its Helm chart

```code
helm uninstall nic -n nginx-ingress
```

2. Delete the namespace

```code
kubectl delete namespace nginx-ingress
```

3. Delete custom resources

```code
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.0/deploy/crds.yaml
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.5.0/deploy/crds-nap-waf.yaml
```
