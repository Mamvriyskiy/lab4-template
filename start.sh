export YC_SERVICE_ACCOUNT_KEY_FILE=sa-key.json
yc config set service-account-key sa-key.json
yc config set cloud-id b1gc22nq88j1ubeekuaq
yc config set folder-id b1gtbc67fv6n4vd28msi
mkdir -p ~/.kube
yc managed-kubernetes cluster list
yc managed-kubernetes cluster get-credentials cat7m89db7c3nf4asoq7 --external --force > ~/.kube/config
kubectl cluster-info --kubeconfig ~/.kube/config

helm uninstall ticket || true
helm install ticket ./helm_service -f ./helm_service/values_ticket.yaml
helm uninstall flight || true
helm install flight ./helm_service -f ./helm_service/values_flight.yaml
helm uninstall bonus || true
helm install bonus ./helm_service -f ./helm_service/values_bonus.yaml
helm uninstall gateway || true
helm install gateway ./helm_service -f ./helm_service/values_gateway.yaml
sleep 60

sudo bash -c "echo '158.160.179.204 rsoi-lab.ru' >> /etc/hosts"