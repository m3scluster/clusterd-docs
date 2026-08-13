.PHONY: deploy serve

MDBOOK := $(shell command -v mdbook 2>/dev/null)
MDBOOK_OPEN_ON_GH := $(shell command -v mdbook-open-on-gh 2>/dev/null)

ifeq ($(MDBOOK),)
MDBOOK := nix shell nixpkgs\#mdbook nixpkgs\#mdbook-open-on-gh --command mdbook
else ifeq ($(MDBOOK_OPEN_ON_GH),)
MDBOOK := nix shell nixpkgs\#mdbook-open-on-gh --command $(MDBOOK)
endif

deploy: book
	@echo "====> deploying to github"
	rm -rf /tmp/book
	git worktree add -f /tmp/book gh-pages
	rm -rf /tmp/book/*
	$(MDBOOK) build
	cp -rp book/* /tmp/book/
	cd /tmp/book && \
		git add -A && \
		git commit -m "deployed on $(shell date) by ${USER}" && \
		git push origin gh-pages

serve:
	$(MDBOOK) serve

