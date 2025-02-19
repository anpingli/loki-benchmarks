export GOBIN=$(CURDIR)/bin
export PATH:=$(GOBIN):$(PATH)

include .bingo/Variables.mk

.DEFAULT_GOAL := help

LOKI_NAMESPACE := observatorium-logs-test

LOKI_OPERATOR_REGISTRY ?= anli
LOKI_STORAGE_BUCKET ?= loki-benchmark-anli

LOKI_CONFIG_FILE ?= hack/rhobs-loki-parameters.yaml
LOKI_TEMPLATE_FILE ?= /tmp/observatorium-logs-template.yaml
RHOBS_DEPLOYMENT_FILE ?= /tmp/rhobs-loki-deployment.yaml

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

lint: $(GOLANGCI_LINT) ## Lint the code
	@$(GOLANGCI_LINT) run --timeout=4m

create-rhobs-loki-file: ## Create a yaml file with deployment details for Loki using RHOBS configuration
	curl -O $(LOKI_TEMPLATE_FILE) https://raw.githubusercontent.com/rhobs/configuration/main/resources/services/observatorium-logs-template.yaml
	oc process -f $(LOKI_TEMPLATE_FILE) -p NAMESPACE=$(LOKI_NAMESPACE) -p LOKI_S3_SECRET=test --param-file $(LOKI_CONFIG_FILE) >> $(RHOBS_DEPLOYMENT_FILE)
	rm $(LOKI_TEMPLATE_FILE)
.PHONY:create-rhobs-loki-file

##@ Testing

run-local-benchmarks: $(GINKGO) $(KIND) $(KUSTOMIZE) $(PROMETHEUS) ## Run benchmark on a Kind cluster
	@IS_TESTING=true \
	SCENARIO_CONFIGURATION_DIRECTORY="test" \
	./run.sh observatorium
.PHONY: test-benchmarks

##@ Deployment

run-rhobs-benchmarks: $(GINKGO) $(PROMETHEUS) ## Run benchmark on an OpenShift cluster with RHOBS settings
	@IS_OPENSHIFT=true \
	BENCHMARK_NAMESPACE=$(LOKI_NAMESPACE) \
	LOKI_COMPONENT_PREFIX="observatorium-loki" \
	BENCHMARKING_CONFIGURATION_DIRECTORY="rhobs" \
	./run.sh rhobs $(RHOBS_DEPLOYMENT_FILE) $(LOKI_STORAGE_BUCKET)
.PHONY: run-benchmarks

run-operator-benchmarks: $(GINKGO) $(PROMETHEUS) ## Run benchmark on an OpenShift cluster with Loki Operator
	@IS_OPENSHIFT=true \
	BENCHMARK_NAMESPACE=$(LOKI_NAMESPACE) \
	LOKI_COMPONENT_PREFIX="lokistack-dev" \
	BENCHMARKING_CONFIGURATION_DIRECTORY="operator" \
	./run.sh operator $(LOKI_OPERATOR_REGISTRY) $(LOKI_STORAGE_BUCKET)

run-lokistack-benchmarks: $(GINKGO) $(PROMETHEUS) ## Run benchmark on an OpenShift cluster with Loki Operator
	IS_OPENSHIFT=true \
	BENCHMARK_NAMESPACE=$(LOKI_NAMESPACE) \
	LOKI_COMPONENT_PREFIX="lokistack-dev" \
	BENCHMARKING_CONFIGURATION_DIRECTORY="lokistack" \
	LOKI_STORAGE_BUCKET=$(LOKI_STORAGE_BUCKET) \
	./run.sh lokistack
