# find v2p in directory this file is in
V2P := $(dir $(lastword $(MAKEFILE_LIST)))v2p

# depend on force to always convert files but convert to *.temp and
# then use cmp || mv to avoid needlessly updating the timestamp and
# causing unwanted rebuilds

# override LD_LIBRARY_PATH when running v2p to avoid Xilinx's libraries
# causing errors like this:
# /usr/lib/gcc/i586-suse-linux/4.5/cc1: /opt/Xilinx/13.1/ISE_DS/common/lib/lin/libstdc++.so.6: version `GLIBCXX_3.4.14' not found (required by /usr/lib/libppl_c.so.2)

%.vhd: %.vhm force
	$(info Convert $< -> $@)
	@LD_LIBRARY_PATH='' perl $(V2P) < $< > $@.temp
	@cmp -s $@.temp $@ || mv $@.temp $@
	@rm -f $@.temp

# vhmh lets us run a file through the preprocessor before v2p
%.vhm: %.vhmh force
	$(info Convert $< -> $@)
	@LD_LIBRARY_PATH='' gcc -x c-header -E -P -w -nostdinc -I. -Iconfig $< -o $@.temp
	@cmp -s $@.temp $@ || mv $@.temp $@
	@rm -f $@.temp

%.vhh: %.vhd force
	$(info Convert $< -> $@)
	@LD_LIBRARY_PATH='' gcc -x c-header -E -P -w -nostdinc -I. -Iconfig $< -o $@.temp
	@cmp -s $@.temp $@ || mv $@.temp $@
	@rm -f $@.temp

.PHONY: force
