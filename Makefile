SHELL := /bin/bash
.DEFAULT_GOAL := help

RALPH_SCRIPT := ./ralph.sh

.PHONY: help doctor ralph-run ralph-validate flowchart-install flowchart-build

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make doctor                                  Check local Ralph prerequisites' \
	  '  make ralph-validate                         Validate Codex wiring for the target repo' \
	  '  make ralph-run MAX_ITERATIONS=3             Run the Codex-adapted Ralph loop' \
	  '  make flowchart-install                      Install flowchart dependencies' \
	  '  make flowchart-build                        Build the flowchart frontend'

doctor:
	@echo '==> Ralph doctor'
	@missing=0; \
	for cmd in git codex python3; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "[ok] $$cmd -> $$(command -v $$cmd)"; \
		else \
			echo "[missing] $$cmd"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then exit 1; fi

ralph-run:
	@iterations=$${MAX_ITERATIONS:-10}; \
	echo "==> run Ralph for Codex ($$iterations iterations)"; \
	bash $(RALPH_SCRIPT) "$$iterations"

ralph-validate:
	@echo '==> validate Codex Ralph wiring'
	bash $(RALPH_SCRIPT) --validate

flowchart-install:
	cd flowchart && pnpm install

flowchart-build:
	cd flowchart && pnpm build
