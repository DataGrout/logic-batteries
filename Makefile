.PHONY: test lint check

test:
	swipl -g "run_tests, halt(0)" -t "halt(1)" test/run_all.pl

lint:
	./scripts/check_safety.sh

check: lint test
