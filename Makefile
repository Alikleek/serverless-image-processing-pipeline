TF_BOOTSTRAP := infra/bootstrap
TF_DEV       := infra/envs/dev

# Deploy targets need these (see docs/PROJECT_PLAN.md §7b):
#   AWS_PROFILE=<target-profile> EXPECTED_ACCOUNT_ID=<12 digits> make plan
EXPECTED_ACCOUNT_ID ?=
AWS_REGION          ?=

.PHONY: help fmt validate lint test layer check-account bootstrap init plan apply destroy

help:
	@echo "Local (no AWS):  fmt validate lint test layer"
	@echo "Target account:  bootstrap plan apply destroy  (need AWS_PROFILE + EXPECTED_ACCOUNT_ID)"

# --- Local only -------------------------------------------------------------

fmt:
	terraform fmt -recursive infra

validate:
	terraform fmt -check -recursive infra
	@for d in $(TF_BOOTSTRAP) $(TF_DEV); do \
		echo "== $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$d validate || exit 1; \
	done

lint:
	ruff check src

test:
	pytest -q tests

layer:
	bash layers/pillow/build.sh

# --- Target account ---------------------------------------------------------

check-account:
	@test -n "$(EXPECTED_ACCOUNT_ID)" || { echo "Set EXPECTED_ACCOUNT_ID to the target account ID"; exit 1; }
	@actual=$$(aws sts get-caller-identity --query Account --output text) || exit 1; \
	if [ "$$actual" != "$(EXPECTED_ACCOUNT_ID)" ]; then \
		echo "Refusing: credentials are for $$actual, expected $(EXPECTED_ACCOUNT_ID). Check AWS_PROFILE."; exit 1; \
	fi; \
	echo "Account OK: $$actual"

bootstrap: check-account
	@test -n "$(AWS_REGION)" || { echo "Set AWS_REGION to the project Region"; exit 1; }
	terraform -chdir=$(TF_BOOTSTRAP) init -input=false
	terraform -chdir=$(TF_BOOTSTRAP) apply \
		-var aws_region=$(AWS_REGION) -var expected_account_id=$(EXPECTED_ACCOUNT_ID)

init: check-account
	terraform -chdir=$(TF_DEV) init -input=false -reconfigure -backend-config=backend.hcl

plan: init
	terraform -chdir=$(TF_DEV) plan -var expected_account_id=$(EXPECTED_ACCOUNT_ID) -out=tfplan

apply: check-account
	terraform -chdir=$(TF_DEV) apply tfplan

destroy: init
	terraform -chdir=$(TF_DEV) destroy -var expected_account_id=$(EXPECTED_ACCOUNT_ID)
