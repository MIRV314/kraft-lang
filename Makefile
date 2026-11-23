.PHONY: check dist

check:
	./tests/run.sh
	./tests/cli.sh
	./tests/xkraft.sh
	./tests/new.sh

dist:
	./tools/make-dist.sh
