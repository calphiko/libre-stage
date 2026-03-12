# Minimal makefile for Sphinx documentation

SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = .
BUILDDIR      = _build

.PHONY: help Makefile html-de html-en gettext serve-de serve-en

help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

html-de:
	$(SPHINXBUILD) -b html -D language=de "$(SOURCEDIR)" "$(BUILDDIR)/html/de" $(SPHINXOPTS)

html-en:
	$(SPHINXBUILD) -b html -D language=en "$(SOURCEDIR)" "$(BUILDDIR)/html/en" $(SPHINXOPTS)

gettext:
	$(SPHINXBUILD) -b gettext "$(SOURCEDIR)" "$(BUILDDIR)/gettext" $(SPHINXOPTS)

serve-de:
	python -m http.server 8080 --directory "$(BUILDDIR)/html/de"

serve-en:
	python -m http.server 8081 --directory "$(BUILDDIR)/html/en"

