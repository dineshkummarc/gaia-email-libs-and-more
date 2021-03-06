# full rsync
RSYNC=rsync -avL
# rsync JS files only, ignore jsdoc subdir.
RSYNC_JS=rsync -r -f "- jsdoc/" -f "+ */" -f "+ *.js" -f "- *" --prune-empty-dirs

VOLO=./scripts/volo

# Volo does its transformations in-place, so we need to copy junk across,
#  transform it, then copy it to the destination dir.
NODE_PKGS := mailparser mailcomposer mimelib simplesmtp browserify-builtins

SED_TRANSFORMS_mailcomposer = s/mimelib-noiconv/mimelib/g

TRANS_NODE_PKGS := $(addprefix node-transformed-deps/,$(NODE_PKGS))
DEP_NODE_PKGS := $(addprefix data/deps/,$(NODE_PKGS))

node-transformed-deps:
	mkdir -p node-transformed-deps

$(TRANS_NODE_PKGS): node-transformed-deps
	$(RSYNC) node-deps/$(notdir $@) node-transformed-deps
	$(VOLO) npmrel $@
	$(if $(SED_TRANSFORMS_$(notdir $@)),sed -i -e "$(SED_TRANSFORMS_$(notdir $@))" node-transformed-deps/$(notdir $@)/lib/*.js)

# the cp is for main shims created by volo
$(DEP_NODE_PKGS): $(TRANS_NODE_PKGS)
	mkdir -p $@
	-cp node-transformed-deps/$(notdir $@).js data/deps/
	$(RSYNC_JS) node-transformed-deps/$(notdir $@)/ $@/



xpi: $(DEP_NODE_PKGS)
	$(RSYNC) deps/wmsy/lib/wmsy data/deps/
	$(RSYNC) deps/stringencoding/encoding.js data/deps
	cfx --templatedir=xpi-template $(JSONARG) xpi

# create the XPI and post it to our web browser, assuming we are running with:
# https://addons.mozilla.org/en-US/firefox/addon/autoinstaller/
run: xpi
	wget --post-file=jetpack-tcp-imap-demo.xpi http://localhost:8222/

# Tell the extension to automatically run our sync test logic so we don't need
# to manually hit a bunch of buttons every time (or have to spawn a new firefox
# instance.)
runtest: JSONARG='--static-args={"synctest": true}'
runtest: run

OUR_JS_DEPS := $(wildcard data/lib/rdimap/imapclient/*.js) $(wildcard data/deps/rdcommon/*.js)

gaia-email-opt.js: scripts/gaia-email-opt.build.js scripts/optStart.frag scripts/optEnd.frag $(DEP_NODE_PKGS) $(OUR_JS_DEPS) deps/almond.js
	node scripts/r.js -o scripts/gaia-email-opt.build.js


PYTHON=python
B2GSD=b2g-srcdir-symlink
B2GBD=b2g-builddir-symlink
PYTHONINCDIRS=-I$(B2GSD)/build -I$(B2GBD)/_tests/mozbase/mozinfo
xpcshell-tests:
	$(PYTHON) $(B2GSD)/config/pythonpath.py $(PYTHONINCDIRS) $(B2GSD)/testing/xpcshell/runxpcshelltests.py --symbols-path=$(B2GBD)/dist/crashreporter-symbols --build-info-json=$(B2GBD)/mozinfo.json $(B2GBD)/dist/bin/xpcshell test/unit

SOLO_FILE ?= $(error Specify a test filename in SOLO_FILE when using check-interactive or check-one)

check-one:
	$(PYTHON) $(B2GSD)/config/pythonpath.py $(PYTHONINCDIRS) $(B2GSD)/testing/xpcshell/runxpcshelltests.py --symbols-path=$(B2GBD)/dist/crashreporter-symbols --build-info-json=$(B2GBD)/mozinfo.json --test-path=$(SOLO_FILE) $(B2GBD)/dist/bin/xpcshell test/unit


clean:
	rm -rf data/deps
	rm -rf node-transformed-deps

.DEFAULT_GOAL=xpi
