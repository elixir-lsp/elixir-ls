#
# Simple makefile for distribution and installation
#
INSTALL_DIR ?= ${HOME}/.local/share/elixir-ls

.PHONY: dist install

dist:
	tar cvf elixir-ls-dist.tar config apps mix.exs

install: dist
	mkdir -p ${INSTALL_DIR}
	tar xvCf ${INSTALL_DIR} elixir-ls-dist.tar
	cp ${INSTALL_DIR}/apps/elixir_ls_utils/priv/* ${INSTALL_DIR}
