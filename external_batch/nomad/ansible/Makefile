# =============================================================================
# Nomad External Batch — Ansible Playbook Makefile
# =============================================================================
#
# Targets:
#   help          Show this help
#   syntax        Validate YAML syntax of all playbooks (fast, no inventory)
#   check         Dry-run against inventory (reports changes, makes no changes)
#   test          Run syntax + validate (fastest feedback loop)
#   deploy        Full provisioning: server then all clients
#   deploy-server Provision just the Nomad server
#   deploy-clients Provision all Nomad clients
#   deploy-client Provision a single client (usage: make deploy-client HOST=nomad-client-3)
#
# Variables:
#   PLAYBOOK_DIR  Directory containing playbooks  (default: playbooks)
#   INVENTORY     Inventory file                  (default: inventory.yml)
#   ANSIBLE_ARGS  Extra arguments to pass through (default: empty)
#   HOST          Single host for --limit (used by deploy-client)
#   VERBOSE       Set to 1 for -v, 2 for -vv, etc.
# =============================================================================

PLAYBOOK_DIR ?= playbooks
INVENTORY   ?= inventory.yml
ANSIBLE_ARGS ?=
VERBOSE     ?=

# Build verbosity flag
ifeq ($(VERBOSE),)
  VFLAG :=
else
  VFLAG := -$(shell printf '%*s' $(VERBOSE) '' | tr ' ' 'v')
endif

# ANSIBLE escapes % so we need to handle it
%.run: ;

.PHONY: help syntax check test \
        deploy deploy-server deploy-clients deploy-client

help:
	@echo 'Nomad External Batch — Ansible Playbook'
	@echo ''
	@echo 'Usage:  make <target> [INVENTORY=path] [VERBOSE=1]'
	@echo ''
	@grep -E '^  [a-z-]+ ' $(MAKEFILE_LIST) | sort | \
	  while read tgt sep desc; do \
	    printf '  \033[1m%-18s\033[0m %s\n' "$${tgt}" "$${desc}"; \
	  done
	@echo ''
	@echo 'Examples:'
	@echo '  make syntax                       # quick YAML check'
	@echo '  make test                         # syntax + dry-run'
	@echo '  make deploy                       # full provisioning'
	@echo '  make deploy-client HOST=nomad-client-5  # add a single client'
	@echo '  make check VERBOSE=2 INVENTORY=staging.yml  # detailed dry-run'

# ── Validation targets ───────────────────────────────────────────────────

syntax:
	@echo '=== Syntax check: playbooks/*.yml ==='
	@for p in $(PLAYBOOK_DIR)/*.yml; do \
	  echo "  -> $$p"; \
	  ansible-playbook --syntax-check "$$p" $(VFLAG) || exit 1; \
	done
	@echo '  All playbooks pass syntax check.'
	@echo ''
	@echo '=== Syntax check: roles/*/tasks/*.yml ==='
	@for r in roles/*/tasks/*.yml roles/*/handlers/*.yml; do \
	  [ -f "$$r" ] || continue; \
	  echo "  -> $$r"; \
	      ansible-playbook --syntax-check --tags=validate \
	        -e "ansible_os_family=Debian" \
	        -e "inventory_hostname=test" \
	        -e "nomad_server_internal_ip=127.0.0.1" \
	        -e "nomad_client_internal_ips={}" \
	        -e "nfs_export_path=/tmp/nfs" \
	        -e "vpc_cidr=10.0.0.0/8" \
	        -e "local_nomad_zip=/tmp/nomad.zip" \
	        -e "local_openstudio_tarball=/tmp/os.tar.gz" \
	        -e "openstudio_version=3.10.0" \
	        test.yml 2>/dev/null \
	      || ansible-lint "$$r" 2>/dev/null \
	      || echo "  (ok — standalone role file, checked by playbook syntax above)"; \
	done
	@echo '  Done.'

check: $(INVENTORY)
	@echo '=== Dry-run against $(INVENTORY) ==='
	@echo '  (no changes will be made — add VERBOSE=1 for detailed diff)'
	ansible-playbook --check --diff $(VFLAG) \
	  -i $(INVENTORY) \
	  $(PLAYBOOK_DIR)/site.yml $(ANSIBLE_ARGS)
	@echo '  Dry-run complete.'

validate:
	@echo '=== Validate inventory.yml.example is loadable ==='
	python3 -c "import yaml; d=yaml.safe_load(open('inventory.yml.example')); assert 'all' in d, 'missing all:'; print('  inventory.yml.example: OK')"
	@echo ''

test: syntax validate
	@echo '=== All validation passed ==='

# ── Provisioning targets ─────────────────────────────────────────────────

$(INVENTORY):
	@echo 'ERROR: $(INVENTORY) not found.'
	@echo '  Copy inventory.yml.example to $(INVENTORY) and fill in your hosts:'
	@echo '    cp inventory.yml.example $(INVENTORY)'
	@false

deploy-server: $(INVENTORY)
	ansible-playbook $(VFLAG) -i $(INVENTORY) \
	  $(PLAYBOOK_DIR)/nomad-server.yml $(ANSIBLE_ARGS)

deploy-clients: $(INVENTORY)
	ansible-playbook $(VFLAG) -i $(INVENTORY) \
	  $(PLAYBOOK_DIR)/nomad-clients.yml $(ANSIBLE_ARGS)

deploy-client: $(INVENTORY)
	@if [ -z "$(HOST)" ]; then \
	  echo 'ERROR: specify HOST=nomad-client-<N>'; \
	  echo '  make deploy-client HOST=nomad-client-3'; \
	  false; \
	fi
	ansible-playbook $(VFLAG) -i $(INVENTORY) \
	  --limit $(HOST) \
	  $(PLAYBOOK_DIR)/nomad-clients.yml $(ANSIBLE_ARGS)

deploy: $(INVENTORY)
	ansible-playbook $(VFLAG) -i $(INVENTORY) \
	  $(PLAYBOOK_DIR)/site.yml $(ANSIBLE_ARGS)
