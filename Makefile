.PHONY: check

check:
	./tests/run.sh
	./tests/cli.sh
	./tests/xkraft.sh
