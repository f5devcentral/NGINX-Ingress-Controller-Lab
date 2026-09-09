# Lab deployment

See the [prerequisites](/README.md#getting-started)

This deployment is for NGINX Ingress Controller and F5 WAF for NGINX with precompiled WAF policies and log profiles

## Installing

1. Clone this repository and `cd` into it
```code
git clone https://github.com/f5devcentral/NGINX-Ingress-Controller-Lab.git
cd NGINX-Ingress-Controller-Lab
```

2. Create NGINX Ingress Controller namespace

```code
kubectl create namespace nginx-ingress
```

3. Create Kubernetes secret to pull images from NGINX private registry

```code
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. Create Kubernetes secret holding the NGINX Plus license

```code
kubectl create secret generic license-token --from-file=license.jwt=<nginx-one-eval.jwt> --type=nginx.com/license -n nginx-ingress
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

5. List available NGINX Ingress Controller docker images that include NGINX App Protect WAF

```code
curl -s https://private-registry.nginx.com/v2/nginx-ic-nap-v5/nginx-plus-ingress/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`5.6.1` at the time of writing)

6. Apply NGINX Ingress Controller custom resources (make sure the URI below references the latest available `5.x` NGINX Ingress Controller version)
```code
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.6.1/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.6.1/deploy/crds-nap-waf.yaml
```

7. Create the PVCs to store compiled WAF policy bundles and logging profiles
```code
kubectl apply -f ./deployment/pvcs.yaml
```

8. Install NGINX Ingress Controller with NGINX App Protect through its Helm chart (set `nginx.image.tag` to the latest `5.x` available NGINX Ingress Controller version and adjust the chart version accordingly)

```code
helm install nic oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.7.1 \
  --set controller.image.repository=private-registry.nginx.com/nginx-ic-nap-v5/nginx-plus-ingress \
  --set controller.image.tag=5.6.1 \
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

9. Check NGINX Ingress Controller pod status

```code
kubectl get pods -n nginx-ingress
```

Pod should be in the `Running` state

```code
NAME                                           READY   STATUS    RESTARTS   AGE
nic-nginx-ingress-controller-fc7546d97-9lcbk   3/3     Running   0          22s
```

10. Check NGINX Ingress Controller logs

```code
kubectl logs -l app.kubernetes.io/instance=nic -n nginx-ingress -c nginx-ingress
```

Output should be similar to the following

```code
2026/09/03 08:48:52 [notice] 13#13: worker process 18 exited with code 0
2026/09/03 08:48:52 [notice] 13#13: signal 29 (SIGIO) received
I20260903 08:48:52.110116   1 main.go:112] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress", UID:"20fd003a-009f-4176-9881-eb1b1627af01", APIVersion:"v1", ResourceVersion:"225394316", FieldPath:""}): type: 'Normal' reason: 'Updated' ConfigMap nginx-ingress/nic-nginx-ingress updated without error
I20260903 08:48:52.110176   1 main.go:112] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"nginx-ingress", Name:"nic-nginx-ingress-mgmt", UID:"7906d15b-c28d-4dd8-9c41-68ba84f2e1ce", APIVersion:"v1", ResourceVersion:"225394315", FieldPath:""}): type: 'Normal' reason: 'Updated' MGMT ConfigMap nginx-ingress/nic-nginx-ingress-mgmt updated without error
2026/09/03 08:48:52 [notice] 13#13: signal 17 (SIGCHLD) received from 19
2026/09/03 08:48:52 [notice] 13#13: worker process 19 exited with code 0
2026/09/03 08:48:52 [notice] 13#13: signal 29 (SIGIO) received
```

11. Check Kubernetes service status

```code
kubectl get svc -n nginx-ingress
```

NGINX Ingress Controller should be listening on TCP ports 80 and 443

```code
NAME                           TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
nic-nginx-ingress-controller   NodePort   10.99.199.74   <none>        80:32507/TCP,443:31477/TCP   71s
```

12. Check the `ingressclass`

```code
kubectl get ingressclass
```

The `nginx` ingressclass should be available

```code
NAME    CONTROLLER                     PARAMETERS   AGE
nginx   nginx.org/ingress-controller   <none>       85s
```

## Build the WAF compiler

1. List available F5 WAF for NGINX compiler versions
```code
curl -s https://private-registry.nginx.com/v2/nap/waf-compiler/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

2. Set up Docker to authenticate to the private registry
```code
sudo mkdir -p /etc/docker/certs.d/private-registry.nginx.com
sudo cp <nginx-one-eval.crt> /etc/docker/certs.d/private-registry.nginx.com/client.cert
sudo cp <nginx-one-eval.key> /etc/docker/certs.d/private-registry.nginx.com/client.key
```

3. Build the F5 WAF for NGINX compiler (`5.15.0` at the time of writing):
```code
docker build -f deployment/Dockerfile --no-cache --platform linux/amd64 \
  --secret id=nginx-crt,src=<nginx-one-eval.crt> \
  --secret id=nginx-key,src=<nginx-one-eval.key> \
  -t waf-compiler-5.15.0:custom .
```

4. The output should be similar to the following
```code
 => [internal] load build definition from Dockerfile                                                                                                                                                                           0.3s
 => => transferring dockerfile: 1.36kB                                                                                                                                                                                         0.0s
 => resolve image config for docker-image://docker.io/docker/dockerfile:1                                                                                                                                                      1.4s
 => [auth] docker/dockerfile:pull token for registry-1.docker.io                                                                                                                                                               0.0s
 => docker-image://docker.io/docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32                                                                                                       2.9s
 => => resolve docker.io/docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32                                                                                                           0.2s
 => => sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32 9.08kB / 9.08kB                                                                                                                                 0.0s
 => => sha256:34b128e419449565adc5ed7f487a6f503a73f1077012cfed86354c731338c44f 1.13kB / 1.13kB                                                                                                                                 0.0s
 => => sha256:c844dc65644b70ea8b391444db20ff38537384d800ea9896d46ab8f3ce897f51 1.33kB / 1.33kB                                                                                                                                 0.0s
 => => sha256:9f624ef51ad55db0ea52d755cc777566386156106fbb4f465eecb22c67ac55ed 14.14MB / 14.14MB                                                                                                                               2.2s
 => => extracting sha256:9f624ef51ad55db0ea52d755cc777566386156106fbb4f465eecb22c67ac55ed                                                                                                                                      0.2s
 => [internal] load metadata for private-registry.nginx.com/nap/waf-compiler:5.13.4                                                                                                                                            0.6s
 => [internal] load .dockerignore                                                                                                                                                                                              0.1s
 => => transferring context: 2B                                                                                                                                                                                                0.0s
 => [stage-0 1/2] FROM private-registry.nginx.com/nap/waf-compiler:5.13.4@sha256:4076d5eeda51fa7fd36ad9843d057eb73651c9c9900ee49916ec4132fb334170                                                                             40.2s
 => => resolve private-registry.nginx.com/nap/waf-compiler:5.13.4@sha256:4076d5eeda51fa7fd36ad9843d057eb73651c9c9900ee49916ec4132fb334170                                                                                      0.0s
 => => sha256:2b3eae2954d26df7120304c9d858ed34e83ce12104d5ae9e782a0635dae6d9a8 53.62MB / 53.62MB                                                                                                                              20.4s
 => => sha256:4076d5eeda51fa7fd36ad9843d057eb73651c9c9900ee49916ec4132fb334170 1.58kB / 1.58kB                                                                                                                                 0.0s
 => => sha256:043d3c43881aec778f347f1775f20fbe162cb2e7d56bfcd625d032a5b31db17c 5.18kB / 5.18kB                                                                                                                                 0.0s
 => => sha256:1d0c5c3a85905b425efa55b278a29ee6685814847d91ad32fc91490cabe886ed 30.65MB / 30.65MB                                                                                                                              11.4s
 => => sha256:48ef0c5f7c213256812e4bf9e1b7c64c6a9d6fb4bf845a55fc90336f533e2a45 637B / 637B                                                                                                                                     0.2s
 => => sha256:42ab8b69ac4a6dd65385e163bafc993f876b9fe50f68d270d6ce76aa91def229 3.07MB / 3.07MB                                                                                                                                 1.6s
 => => sha256:0ffa98b69097c81a982974ee0f90ec957c0a1a36bc3311670ef5cd62291f5740 21.33MB / 21.33MB                                                                                                                               8.4s
 => => sha256:bb939547934f31035317544edba19fa0476c021f7849c12e63e88164c4c2e6ce 100.43MB / 100.43MB                                                                                                                            33.1s
 => => extracting sha256:1d0c5c3a85905b425efa55b278a29ee6685814847d91ad32fc91490cabe886ed                                                                                                                                      1.6s
 => => extracting sha256:2b3eae2954d26df7120304c9d858ed34e83ce12104d5ae9e782a0635dae6d9a8                                                                                                                                      1.1s
 => => extracting sha256:48ef0c5f7c213256812e4bf9e1b7c64c6a9d6fb4bf845a55fc90336f533e2a45                                                                                                                                      0.0s
 => => extracting sha256:42ab8b69ac4a6dd65385e163bafc993f876b9fe50f68d270d6ce76aa91def229                                                                                                                                      0.1s
 => => extracting sha256:0ffa98b69097c81a982974ee0f90ec957c0a1a36bc3311670ef5cd62291f5740                                                                                                                                      0.2s
 => => extracting sha256:bb939547934f31035317544edba19fa0476c021f7849c12e63e88164c4c2e6ce                                                                                                                                      5.6s
 => [stage-0 2/2] RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644     --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644     apt-get update     && apt-get instal  63.3s
 => exporting to image                                                                                                                                                                                                         0.6s
 => => exporting layers                                                                                                                                                                                                        0.4s
 => => writing image sha256:3f345ec5d1ad3d08cbed5082e209e916cda912dbcd32d24b63cc2f5ef16862cd                                                                                                                                   0.0s
 => => naming to docker.io/library/waf-compiler-5.15.0:custom                                                                                                                                                                  0.1s
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
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.6.1/deploy/crds.yaml
kubectl delete -f https://raw.githubusercontent.com/nginx/kubernetes-ingress/v5.6.1/deploy/crds-nap-waf.yaml
```
