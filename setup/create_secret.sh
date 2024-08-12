kubectl create namespace nginx-ingress
kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com \
  --docker-username=<JWT token goes here> \
  --docker-password=none -n nginx-ingress