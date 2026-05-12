.PHONY: test lint check registry check-registry check-pl

test:
	swipl -g "run_tests, halt(0)" -t "halt(1)" test/run_all.pl

lint:
	./scripts/check_safety.sh

check-pl:
	@echo "Checking Prolog syntax..."; \
	fail=0; \
	for f in $$(find modules -name "*.pl"); do \
		swipl -q -l scripts/check_prelude.pl -g halt "$$f" 2>/dev/null || { echo "FAIL: $$f"; fail=1; }; \
	done; \
	[ $$fail -eq 0 ] && echo "All .pl files OK" || exit 1

registry:
	python3 scripts/build_registry.py

check-registry:
	python3 scripts/build_registry.py --check

check: lint check-pl check-registry
