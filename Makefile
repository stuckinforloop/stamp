TOOLS_DIR := $(CURDIR)/bin/tools

GOLANGCI_LINT_VERSION := 2.12.2
GOLANGCI_LINT := $(TOOLS_DIR)/golangci-lint

.DEFAULT_GOAL := help

# Prints every target that carries a "##" description.
.PHONY: help
help: ## Show this help.
	@echo "Usage: make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / { printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: build
build: ## Compile every package.
	go build ./...

# Recursive make keeps the stages ordered even under "make -j". Formatting
# runs first: the linter reports formatter differences as findings, so an
# unformatted tree buries the real ones. CI systems set CI, which drops the
# format stage — rewriting files nobody will commit helps no one.
.PHONY: verify
verify: ## Format, lint, test, and build. The gate for a unit of work.
	$(if $(CI),,$(MAKE) fmt)
	$(MAKE) lint
	$(MAKE) test
	$(MAKE) build

.PHONY: fmt
fmt: tools ## Format the code.
	$(GOLANGCI_LINT) fmt ./...

.PHONY: lint
lint: tools ## Report lint and format problems.
	$(GOLANGCI_LINT) run ./...

.PHONY: test
test: ## Run the tests with the race detector.
	go test -race ./...

# Installs only when the binary is missing or is the wrong version. The
# version check costs about 40ms, so every target below can depend on it.
.PHONY: tools
tools: ## Install the dev tools into bin/tools.
	@if [ "$$($(GOLANGCI_LINT) version --short 2>/dev/null)" = "$(GOLANGCI_LINT_VERSION)" ]; then exit 0; fi; \
	echo "installing golangci-lint v$(GOLANGCI_LINT_VERSION) into $(TOOLS_DIR)"; \
	mkdir -p $(TOOLS_DIR); \
	GOBIN=$(TOOLS_DIR) go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v$(GOLANGCI_LINT_VERSION)

.PHONY: tools-clean
tools-clean: ## Delete bin/tools.
	rm -rf $(TOOLS_DIR)
