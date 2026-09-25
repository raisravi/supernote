# SuperNote development tasks. See docs/DEVELOPMENT.md.
PLUGIN_ID := supernote
QMLLINT   ?= $(firstword $(wildcard /usr/lib/qt6/bin/qmllint) qmllint)
DMS_PLUGINS ?= $(HOME)/.config/DankMaterialShell/plugins

.PHONY: test lint reload restart link mdit help

help:
	@echo "make test      run all unit + shell tests"
	@echo "make lint      qmllint every QML file"
	@echo "make reload    reload only the entry file (dms ipc call plugins reload)"
	@echo "make restart   restart DMS (needed after editing any other QML/JS file: they are cached)"
	@echo "make link      symlink this checkout into the DMS plugins folder"
	@echo "make mdit      regenerate js/mdit.js from vendor/markdown-it.min.js"

test:
	@tests/run-all.sh

lint:
	@$(QMLLINT) $$(git ls-files '*.qml') 2>&1 | grep -E '^Error' && exit 1 || echo "qmllint: no errors"

reload:
	dms ipc call plugins reload $(PLUGIN_ID)

restart:
	dms restart

link:
	@test ! -e "$(DMS_PLUGINS)/$(PLUGIN_ID)" || { echo "$(DMS_PLUGINS)/$(PLUGIN_ID) already exists"; exit 1; }
	ln -s "$(CURDIR)" "$(DMS_PLUGINS)/$(PLUGIN_ID)"

mdit:
	scripts/dev/build-mdit.sh
