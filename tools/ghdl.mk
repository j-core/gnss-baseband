# This is a makefile snippet useful for simulating with ghdl on both
# Linux and OSX. On both platforms it will create a create an
# executable file that can be used to run the simulation.

# To use this, set VHDL_TOPS and optionally VHDL_LIBS (described
# below), define the dependicies between the vhdl library file and vhd
# files it will contain, and include this file.

# For example:
#
# VHDL_TOPS := foo
# work-obj93.cf: foo.vhd foo_pkg.vhd
# include tools/ghdl.mk
#
# Variables that can be set to modify this files behaviour:
# VHDL_TOPS = names of top entities that will be simulated
# VHDL_LIBS = names of VHDL libraries. Defaults to "work"

ifeq ($(VHDL_TOPS),)
$(error Need to set VHDL_TOPS)
endif

include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

VHDL_LIBS ?= work
VHDL_LIBS := $(addsuffix -obj93.cf,$(VHDL_LIBS))

GHDL ?= ghdl
GHDL_EXISTS := $(shell sh -c 'which $(GHDL) >/dev/null && echo true')

ifeq ($(GHDL_EXISTS),true)
%-obj93.cf:
	$(GHDL) -i --work=$* $(filter %.vhh %.vhd %.vhdl,$^)

# look at ghdl --version output to determine backend generator type
define check_backend
(ghdl --version 2> /dev/null | grep -i "$(1).*generator" -q) && echo y
endef

GHDL_BACKEND_GCC := $(shell $(call check_backend,gcc))
GHDL_BACKEND_LLVM := $(shell $(call check_backend,llvm))
GHDL_BACKEND_MCODE := $(shell $(call check_backend,mcode))

ifeq ($(GHDL_BACKEND_GCC)$(GHDL_BACKEND_LLVM),y)
# for compiler backends, use -m to compile binaries for each top
$(VHDL_TOPS): $(VHDL_LIBS)
	$(GHDL) -m -fexplicit --ieee=synopsys $@
else
ifeq ($(GHDL_BACKEND_MCODE),y)
# With an mcode backend, create wrapper scripts that compile and run
# the test benches
$(VHDL_TOPS): $(VHDL_LIBS)
	echo "#!/bin/sh" > $@
	echo 'ghdl -c -fexplicit --ieee=synopsys -r $@ $$@' >> $@
	chmod +x $@
else
$(error Unrecognized GHDL backend)
endif
endif

endif

#clean::
#	-$(GHDL) --remove
#	rm -f *.lst
