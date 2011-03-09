PACKAGE=grok

PLATFORM=$(shell (uname -o || uname -s) 2> /dev/null)
FLEX?=flex

FORCE_FLEX?=0

ifeq ($(PLATFORM), FreeBSD)
PREFIX?=/usr/local
else
PREFIX?=/usr
endif

# On FreeBSD, you may want to set GPERF=/usr/local/bin/gperf since
# the base system gperf is too old.
ifeq ($(PLATFORM), FreeBSD)
GPERF?=/usr/local/bin/gperf
else
GPERF?=/usr/bin/gperf
endif

# For linux, we need libdl for dlopen()
# On FreeBSD, comment this line out.
ifeq ($(PLATFORM), GNU/Linux)
LDFLAGS+=-ldl
endif

# #############################################
# You probably don't need to make changes below

BASE?=.
MAJOR=$(shell sh $(BASE)/version.sh --major)
VERSION=$(shell sh $(BASE)/version.sh)

#CFLAGS+=-g
#LDFLAGS+=-g

CFLAGS+=-pipe -fPIC -I. -O2
LDFLAGS+=-lpcre -levent -rdynamic -ltokyocabinet

LIBSUFFIX=$(shell sh $(BASE)/platform.sh libsuffix)
VERLIBSUFFIX=$(shell sh $(BASE)/platform.sh libsuffix $(MAJOR))
DYNLIBFLAG=$(shell sh $(BASE)/platform.sh dynlibflag)
LIBNAMEFLAG=$(shell sh $(BASE)/platform.sh libnameflag $(MAJOR) $(INSTALLLIB))

# Sane includes
CFLAGS+=-I/usr/local/include
LDFLAGS+=-L/usr/local/lib

# Uncomment to totally disable logging features
#CFLAGS+=-DNOLOGGING

EXTRA_CFLAGS?=
EXTRA_LDFLAGS?=
CFLAGS+=$(EXTRA_CFLAGS)
LDFLAGS+=$(EXTRA_LDFLAGS)

### End of user-servicable configuration

CLEANGEN=filters.c grok_matchconf_macro.c *.yy.c *.tab.c *.tab.h
CLEANOBJ=*.o *_xdr.[ch]
CLEANBIN=main grokre grok conftest grok_program
CLEANVER=VERSION grok_version.h grok.spec

GROKOBJ=grok.o grokre.o grok_capture.o grok_pattern.o stringhelper.o \
        predicates.o grok_capture_xdr.o grok_match.o grok_logging.o \
        grok_program.o grok_input.o grok_matchconf.o libc_helper.o \
        grok_matchconf_macro.o filters.o grok_discover.o
GROKPROGOBJ=grok_input.o grok_program.o grok_matchconf.o $(GROKOBJ)

GROKHEADER=grok.h grok_pattern.h grok_capture.h grok_capture_xdr.h \
           grok_match.h grok_logging.h grok_discover.h

# grok_version.h is generated by make.
GROKHEADER+=grok_version.h

.PHONY: all
all: grok discogrok libgrok.$(LIBSUFFIX) libgrok.$(VERLIBSUFFIX)

.PHONY: package create-package test-package update-version
package: 
	$(MAKE) $(MAKEFLAGS) create-package 
	$(MAKE) $(MAKEFLAGS) test-package 

install: libgrok.$(LIBSUFFIX) grok discogrok $(GROKHEADER)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -d $(DESTDIR)$(PREFIX)/lib
	install -d $(DESTDIR)$(PREFIX)/include
	install -m 755 grok $(DESTDIR)$(PREFIX)/bin
	install -m 755 discogrok $(DESTDIR)$(PREFIX)/bin
	install -m 644 libgrok.$(LIBSUFFIX) $(DESTDIR)$(PREFIX)/lib
	for header in $(GROKHEADER); do \
		install -m 644 $$header $(DESTDIR)$(PREFIX)/include; \
	done 
	install -d $(DESTDIR)$(PREFIX)/share/grok
	install -d $(DESTDIR)$(PREFIX)/share/grok/patterns
	install patterns/base $(DESTDIR)$(PREFIX)/share/grok/patterns/

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/grok
	rm -f $(DESTDIR)$(PREFIX)/bin/discogrok
	rm -f $(DESTDIR)$(PREFIX)/lib/libgrok.so
	for header in $(GROKHEADER); do \
		rm -f $(DESTDIR)$(PREFIX)/include/$$header; \
	done 
	rm -f $(DESTDIR)$(PREFIX)/share/grok/patterns/*

pre-create-package:
	rm -f VERSION grok_version.h

create-package: pre-create-package 
	$(MAKE) VERSION grok_version.h grok.spec
	PACKAGE=$(PACKAGE) sh package.sh $(VERSION)

test-package:
	PKGVER=$(PACKAGE)-$(VERSION); \
	tar -C /tmp -zxf $${PKGVER}.tar.gz; \
	echo "Running C tests..." && $(MAKE) -C /tmp/$${PKGVER}/test test-c

.PHONY: clean 
clean: cleanobj cleanbin

# reallyreallyclean also purges generated files
# we don't clean generated files in 'clean' target
# because some systems don't have the tools to regenerate
# the data, such as FreeBSD which has the wrong flavor
# of flex (not gnu flex)
.PHONY: reallyreallyclean
reallyreallyclean: reallyclean cleangen

.PHONY: reallyclean
reallyclean: clean cleanver

.PHONY: cleanobj
cleanobj:
	rm -f $(CLEANOBJ)

.PHONY: cleanbin
cleanbin:
	rm -f $(CLEANBIN)

.PHONY: cleangen
cleangen:
	rm -f $(CLEANGEN)

.PHONY: cleanver
cleanver:
	rm -f $(CLEANVER)

#.PHONY: test
#test:
	#$(MAKE) -C test test

# Binary creation
grok: LDFLAGS+=-levent
grok: $(GROKOBJ) conf.tab.o conf.yy.o main.o grok_config.o
	gcc $(LDFLAGS) $^ -o $@

discogrok: $(GROKOBJ) discover_main.o
	gcc $(LDFLAGS) $^ -o $@

libgrok.$(LIBSUFFIX): 
libgrok.$(LIBSUFFIX): $(GROKOBJ) 
	gcc $(LDFLAGS) -fPIC $(DYNLIBFLAG) $(LIBNAMEFLAG) $^ -o $@

libgrok.$(VERLIBSUFFIX): libgrok.$(LIBSUFFIX);
	ln -s $< $@

# File dependencies
# generated with: 
# for i in *.c; do grep '#include "' $i | fex '"2' | xargs | sed -e "s/^/$i: /"; done    
grok.h: grok_version.h
grok.c: grok.h
grok_capture.c: grok.h grok_capture.h grok_capture_xdr.h
grok_capture_xdr.c: grok_capture.h
grok_config.c: grok_input.h grok_config.h grok_matchconf.h grok_logging.h
grok_input.c: grok.h grok_program.h grok_input.h grok_matchconf.h grok_logging.h libc_helper.h
grok_logging.c: grok.h
grok_match.c: grok.h
grok_matchconf.c: grok.h grok_matchconf.h grok_matchconf_macro.h grok_logging.h libc_helper.h filters.h stringhelper.h
grok_pattern.c: grok.h grok_pattern.h
grok_program.c: grok.h grok_program.h grok_input.h grok_matchconf.h
grokre.c: grok.h predicates.h stringhelper.h grok_version.h
libc_helper.c: libc_helper.h
main.c: grok.h grok_program.h grok_config.h conf.tab.h
predicates.c: grok_logging.h predicates.h
stringhelper.c: stringhelper.h
filters.h: grok.h
grok.h: grok_logging.h grok_pattern.h grok_capture.h grok_match.h
grok_capture.h: grok_capture_xdr.h
grok_config.h: grok_program.h
grok_input.h: grok_program.h
grok_match.h: grok_capture_xdr.h
grok_matchconf.h: grok.h grok_input.h grok_program.h
predicates.h: grok.h


# Output generation
grok_capture_xdr.o: grok_capture_xdr.c grok_capture_xdr.h
grok_capture_xdr.c: grok_capture.x
	[ -f $@ ] && rm $@ || true
	rpcgen -c $< -o $@
grok_capture_xdr.h: grok_capture.x
	[ -f $@ ] && rm $@ || true
	rpcgen -h $< -o $@

%.c: %.gperf
	@if $(GPERF) --version | head -1 | egrep -v '3\.[0-9]+\.[0-9]+' ; then \
		echo "We require gperf version >= 3.0.3" ; \
		exit 1; \
	fi
	$(GPERF) $< > $@

conf.tab.c conf.tab.h: conf.y
	bison -d $<

conf.yy.c: conf.lex conf.tab.h
	@if $(FLEX) --version | grep '^flex version' ; then \
		if [ "$(FORCE_FLEX)" -eq 1 ] ; then \
			echo "Bad version of flex detected, but FORCE_FLEX is set, trying anyway."; \
			exit 0; \
		fi; \
		echo "Fatal - cannot build"; \
		echo "You need GNU flex. You seem to have BSD flex?"; \
		strings `which flex` | grep Regents; \
		echo "If you want to try your flex, anyway, set FORCE_FLEX=1"; \
		exit 1; \
	fi
	$(FLEX) -o $@ $<

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

%.1: %.pod
	pod2man -c "" -r "" $< $@

grok_version.h:
	sh $(BASE)/version.sh --header > $@

VERSION:
	sh $(BASE)/version.sh --shell > $@

grok.spec: grok.spec.template VERSION
	. ./VERSION;
	sed -e "s/^Version: .*/Version: $(VERSION)/" grok.spec.template > grok.spec


.PHONY: docs
docs:
	doxygen

.PHONY: package-debian
package-debian: debian
	CFLAGS="$(CFLAGS)" debuild -uc -us

package-debian-clean:
	rm -r debian || true

debian:
	dh_make -s -n -c bsd -e $$USER -p grok_$(VERSION) < /dev/null
	sed -i -e "s/Build-Depends:.*/&, bison, ctags, flex, gperf, libevent-dev, libpcre3-dev, libtokyocabinet-dev/" debian/control
	sed -i -e "s/Depends:.*/&, libevent-1.4-2 (>= 1.3), libtokyocabinet8 (>= 1.4.9), libpcre3 (>= 7.6)/" debian/control
	sed -i -e "s/^Description:.*/Description: A powerful pattern-matching and reacting tool./" debian/control
	sed -i -e "/^Description/,$$ { /^ *$$/d }" debian/control
	echo '#!/bin/sh' > debian/postinst
	echo '[ "$$1" = "configure" ] && ldconfig' >> debian/postinst
	echo 'exit 0' >> debian/postinst
	echo '#!/bin/sh' > debian/postrm
	echo '[ "$$1" = "remove" ] && ldconfig' >> debian/postrm
	echo 'exit 0' >> debian/postrm
	chmod 755 debian/postinst debian/postrm


