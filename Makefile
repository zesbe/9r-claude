.PHONY: install uninstall test lint clean help

PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

BINS := hermes-claude kiro2claude kiro2claude-summary kiro-compact

help:
	@echo "hermes-claude — Makefile targets"
	@echo ""
	@echo "  make install      install ke $(BINDIR) (symlinks)"
	@echo "  make uninstall    hapus symlinks"
	@echo "  make test         run smoke tests"
	@echo "  make lint         shellcheck + python lint"
	@echo "  make clean        cleanup"

install:
	@mkdir -p $(BINDIR)
	@for b in $(BINS); do \
		install -Dm755 bin/$$b $(BINDIR)/$$b && \
		echo "installed: $(BINDIR)/$$b"; \
	done
	@echo ""
	@echo "Done. Pastikan $(BINDIR) ada di PATH:"
	@echo "  echo \$$PATH | tr ':' '\\n' | grep -q $(BINDIR) || echo 'export PATH=$(BINDIR):\$$PATH' >> ~/.bashrc"
	@echo ""
	@echo "Next: hermes-claude config"

uninstall:
	@for b in $(BINS); do \
		rm -f $(BINDIR)/$$b && echo "removed: $(BINDIR)/$$b"; \
	done

test:
	@echo "==> smoke test: hermes-claude version"
	@bin/hermes-claude version
	@echo ""
	@echo "==> smoke test: kiro2claude-summary --help"
	@bin/kiro2claude-summary --help | head -5
	@echo ""
	@echo "==> smoke test: kiro-compact --help"
	@bin/kiro-compact --help | head -5

lint:
	@command -v shellcheck >/dev/null && shellcheck bin/hermes-claude || echo "skip: shellcheck not installed"
	@command -v python3 >/dev/null && python3 -m py_compile bin/kiro2claude bin/kiro2claude-summary bin/kiro-compact && echo "python: ok" || echo "python lint failed"

clean:
	@find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name '*.pyc' -delete 2>/dev/null || true
