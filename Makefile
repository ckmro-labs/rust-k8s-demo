SERVICE_IP = $(kubectl get svc --selector=app=frontend,component=loadbalancer -o json | jq --raw-output ".items[0].status.loadBalancer.ingress[0].ip")

PHONY: update-proto
update-proto: # Update protobuf definitions for all microservices
	cp proto/quotation.proto quotationservice/proto
	cp proto/quotation.proto frontendservice/proto

PHONY: bootstrap
bootstrap:
	kubectl create namespace metallb-system
	kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(shell openssl rand -base64 128)"
	kubectl create secret generic postgres-password --from-literal=pgpassword=panda

.PHONY: e2e
e2e: $(SERVICE_IP)
	skaffold run
	kubectl rollout status --timeout 2m -w deployments/postgres-deployment
	kubectl rollout status --timeout 2m -w deployments/quotationservice
	kubectl rollout status --timeout 2m -w deployments/frontendservice
	@echo "Frontend service loadbalancer ip: $(value SERVICE_IP)"
	test 200 = $$(curl -sL -w "%{http_code}\\n" http://$(value SERVICE_IP) -o /dev/null)

.PHONY: help
help: # Show this help
	@{ \
	echo 'Targets:'; \
	echo ''; \
	grep '^[a-z/.-]*: .*# .*' Makefile \
	| sort \
	| sed 's/: \(.*\) # \(.*\)/ - \2 (deps: \1)/' `: fmt targets w/ deps` \
	| sed 's/:.*#/ -/'                            `: fmt targets w/o deps` \
	| sed 's/^/    /'                             `: indent`; \
	echo ''; \
	} 1>&2; \
