.PHONY: install uninstall test lint clean help

PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

# 9r-claude adalah binary utama. hermes-claude = symlink ke 9r-claude
# (kompatibilitas dgn user lama).
PRIMARY := 9r-claude
LEGACY  := hermes-claude
EXTRA   := kiro2claude kiro2claude-summary kiro-compact

help:
	@echo "9r-claude — Makefile targets"
	@echo ""
	@echo "  make install      install ke $(BINDIR)"
	@echo "  make uninstall    hapus binary"
	@echo "  make test         run smoke tests"
	@echo "  make lint         shellcheck + python lint"
	@echo "  make clean        cleanup"

install:
	@mkdir -p $(BINDIR)
	@install -Dm755 bin/$(PRIMARY) $(BINDIR)/$(PRIMARY) && echo "installed: $(BINDIR)/$(PRIMARY)"
	@ln -sf $(PRIMARY) $(BINDIR)/$(LEGACY) && echo "linked:    $(BINDIR)/$(LEGACY) -> $(PRIMARY)"
	@for b in $(EXTRA); do \
		install -Dm755 bin/$$b $(BINDIR)/$$b && echo "installed: $(BINDIR)/$$b"; \
	done
	@echo ""
	@echo "Done. Pastikan $(BINDIR) ada di PATH:"
	@echo "  echo \$$PATH | tr ':' '\\n' | grep -q $(BINDIR) || echo 'export PATH=$(BINDIR):\$$PATH' >> ~/.bashrc"
	@echo ""
	@echo "Next: 9r-claude config"

uninstall:
	@rm -f $(BINDIR)/$(PRIMARY) $(BINDIR)/$(LEGACY) && echo "removed: $(PRIMARY) + $(LEGACY)"
	@for b in $(EXTRA); do \
		rm -f $(BINDIR)/$$b && echo "removed: $(BINDIR)/$$b"; \
	done

test:
	@echo "==> smoke test: 9r-claude version"
	@bin/9r-claude version
	@echo ""
	@echo "==> smoke test: 9r-claude --help (head)"
	@bin/9r-claude --help | head -10
	@echo ""
	@echo "==> smoke test: kiro2claude-summary --help"
	@bin/kiro2claude-summary --help | head -5
	@echo ""
	@echo "==> smoke test: kiro-compact --help"
	@bin/kiro-compact --help | head -5

lint:
	@command -v shellcheck >/dev/null && shellcheck bin/9r-claude || echo "skip: shellcheck not installed"
	@command -v python3 >/dev/null && python3 -m py_compile bin/kiro2claude bin/kiro2claude-summary bin/kiro-compact && echo "python: ok" || echo "python lint failed"

clean:
	@find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name '*.pyc' -delete 2>/dev/null || true
