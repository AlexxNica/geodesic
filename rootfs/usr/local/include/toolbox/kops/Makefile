include helpers
include all

## Initialze module
init:
	@mkdir -p $(KOPS_STATE_STORE_PATH)

## Export kubeconfig
export-kubecfg: validate
	$(KOPS_BIN) export kubecfg --name $(KOPS_NAME)

## Export kops configuration
backup-config: validate init
	@echo "Writing configuration to $(KOPS_STATE_STORE_PATH)/kops.yaml"
	@$(KOPS_BIN) get cluster -o yaml --full > $(KOPS_STATE_STORE_PATH)/kops.yaml

## Edit cluster configuration
edit: validate
	@$(KOPS_BIN) edit cluster

## Upgrade cluster or apply configuration updates
upgrade: validate confirm
	@$(KOPS_BIN) upgrade cluster \
		--yes
	@cloud kops apply

## Apply pending changes to the cluster's autoscaling group configuration (does not modify running instances)
update: validate confirm
	@$(KOPS_BIN) update cluster \
		--yes

## Rolling rebuild of all instances
rolling-update: validate  confirm
	@$(KOPS_BIN) rolling-update cluster \
		--yes

## Show pending changes
plan: validate
	@$(KOPS_BIN) rolling-update cluster

## Update configuration and perform a rolling-update of all instances
apply: confirm update rolling-update
	@cloud config push

require-short-soa:
	$(call assert-set,KOPS_DNS_ZONE)
	@TTL=`drill -t SOA $(KOPS_DNS_ZONE) | grep '^$(KOPS_DNS_ZONE)' | awk '{print $$2}'`; \
	if [ $$TTL -gt 60 ]; then \
		echo "SOA TTL for $(KOPS_DNS_ZONE) should be 60 seconds or less (current: $${TTL}s); High SOA TTLs cause problems due to negative-cache hits for DNS lookups"; \
		exit 1; \
	fi

validate: require-cluster-mounted require-short-soa
	$(call assert-set,AWS_PROFILE,Run `assume-role` first)
	$(call assert-set,AWS_DEFAULT_PROFILE,Run `assume-role` first)
	$(call assert-set,KUBERNETES_VERSION)
	$(call assert-set,KOPS_NAME)
	$(call assert-set,KOPS_ZONES)
	$(call assert-set,KOPS_DNS_ZONE)
	$(call assert-set,KOPS_ASSOCIATE_PUBLIC_IP)
	$(call assert-set,KOPS_ADMIN_ACCESS)
	$(call assert-set,KOPS_NODE_COUNT)
	$(call assert-set,KOPS_NODE_SIZE)
	$(call assert-set,KOPS_MASTER_SIZE)
	$(call assert-set,KOPS_MASTER_ZONES)
	$(call assert-set,KOPS_STATE_STORE)
	$(call assert-set,KOPS_STATE_STORE_PATH)
	$(call assert-set,KOPS_CONFIG)

## Bring up a new cluster
up: init validate create-ssh-key
	@echo "Creating cluster $(KOPS_NAME)..."
	@rm -f $(REMOTE_PATH)/.bootstrapped
	@$(KOPS_BIN) create cluster \
			--cloud=$(KOPS_CLOUD) \
			--zones=$(KOPS_ZONES) \
			--dns-zone=$(KOPS_DNS_ZONE) \
			--associate-public-ip=$(KOPS_ASSOCIATE_PUBLIC_IP) \
			--admin-access=$(KOPS_ADMIN_ACCESS) \
			--node-count=$(KOPS_NODE_COUNT) \
			--node-size=$(KOPS_NODE_SIZE) \
			--master-size=$(KOPS_MASTER_SIZE) \
			--master-zones=$(KOPS_MASTER_ZONES) \
			--kubernetes-version=$(KUBERNETES_VERSION) \
			--name=$(KOPS_NAME) \
			--ssh-public-key=$(KOPS_SSH_PUBLIC_KEY) \
			--yes

## Checks if kubernetes is online
is-online: validate
	@kubectl get nodes >/dev/null 2>&1; \
	if [ $$? -eq 0 ]; then \
		echo "$(KOPS_NAME) kubernetes is available"; \
		exit 0; \
	else \
		echo "$(KOPS_NAME) kubernetes is not ready"; \
    exit 1; \
  fi

## Wait until cluster online
wait-for-kubernetes: validate
	@twiddle cloud kops is-online

## Export terraform configuration
tf: validate
	@$(KOPS_BIN) update cluster \
		--out=terraform/ \
		--target=terraform

## Tear down an existing cluster
down: validate
	@confirm CLUSTER_NAME
	@$(KOPS_BIN) delete cluster \
		--name=$(KOPS_NAME) \
		--region=$(AWS_REGION) \
		--yes
	@rm -f $(REMOTE_PATH)/.bootstrapped

## Delete SSH key pair for this deployment
delete-ssh-key: validate
	@confirm CLUSTER_NAME
	@rm -f "$(KOPS_SSH_PRIVATE_KEY)" "$(KOPS_SSH_PUBLIC_KEY)"

## Create a unique SSH key for this deployment
create-ssh-key: init validate 
	@if [ -f "$(KOPS_SSH_PRIVATE_KEY)" ]; then \
		echo "SSH key $(KOPS_SSH_PRIVATE_KEY) already exists"; \
		else \
		ssh-keygen -t rsa -N '' -b 8192 -C "$(KOPS_NAME)"  -f "$(KOPS_SSH_PRIVATE_KEY)"; \
		rm -f "$(KOPS_SSH_PUBLIC_KEY)"; \
	fi
	@if [ -f "$(KOPS_SSH_PUBLIC_KEY)" ]; then \
		echo "SSH pub key $(KOPS_SSH_PUBLIC_KEY) already exists"; \
	else \
		ssh-keygen -y -f "$(KOPS_SSH_PRIVATE_KEY)" | tr -d "\n" > "$(KOPS_SSH_PUBLIC_KEY)" ; \
	fi
# Ensure perms are always correct
	@chmod 600 "$(KOPS_SSH_PRIVATE_KEY)"

## Rotate SSH key for deployment
rotate-ssh-key: validate delete-ssh-key create-ssh-key configure-ssh-key apply wait-for-kubernetes

## Add ssh key to agent
add-ssh-key:
	@if [ -f "$${KOPS_STATE_PATH}/id_rsa" ]; then \
		if ssh-add -l | grep -q "$$(ssh-keygen -lf "$${KOPS_STATE_PATH}/id_rsa" | awk '{print $$2}')"; then \
			echo "SSH key already added to agent"; \
		else \
		    chmod 600 "$${KOPS_STATE_PATH}/id_rsa"; \
			ssh-add "$${KOPS_STATE_PATH}/id_rsa"; \
		fi; \
	else \
		echo "Cannot find SSH key: $${KOPS_STATE_PATH}/id_rsa"; \
		exit 1; \
	fi

## List secrets
describe-secrets: validate
	@kops describe secrets

## Upload SSH key to deployment
configure-ssh-key: validate
	@echo "Configuring public ssh key"
	@kops delete secret sshpublickey admin || true
	@kops create secret sshpublickey admin --pubkey=$(KOPS_SSH_PUBLIC_KEY)

## Connect to the cluster using SSH as admin
ssh-as-admin: validate
	@ssh -i $(KOPS_SSH_PRIVATE_KEY) $(SSH_USERNAME)@api.$(KOPS_NAME) || true

## Connect to the cluster using SSH with your SSH_USERNAME
ssh:
	$(call assert-set,SSH_USERNAME)
	$(call assert-set,KOPS_NAME)
	@ssh -A $(SSH_USERNAME)@api.$(KOPS_NAME) || true
