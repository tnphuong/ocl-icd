prefix=/usr/local
exec_prefix=$(prefix)
libdir=$(exec_prefix)/lib

CC=gcc
RUBY=ruby
CFLAGS=-O2
CPPFLAGS+=-Wall -Werror -Wno-cpp -Wno-deprecated-declarations -Wno-comment

OpenCL_SOURCES=ocl_icd.c ocl_icd_lib.c

OpenCL_OBJECTS=$(OpenCL_SOURCES:%.c=%.o)

PRGS=ocl_icd_test ocl_icd_dummy_test

all: library_database


library: test_tools install_test_lib
	$(MAKE) MODE=GENERATOR libOpenCL.so ocl_icd_test

library_database:
	$(MAKE) MODE=DATABASE libOpenCL.so ocl_icd_test

# rules for all modes

ocl_icd_lib.c: icd_generator.rb
ocl_icd.o: ocl_icd.h

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(PRGS): %: %.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBS)

ocl_icd_test: LIBS += -lOpenCL

$(OpenCL_OBJECTS): CFLAGS+= -fpic
libOpenCL.so.1.0: LIBS+= -ldl
libOpenCL.so.1.0: LDFLAGS+= -L.
libOpenCL.so.1.0: $(OpenCL_OBJECTS)
	 $(CC) $(CFLAGS) $(LDFLAGS) -shared -o $@ \
		-Wl,-Bsymbolic -Wl,-soname,libOpenCL.so \
		$(filter %.o,$^) $(LIBS)

libOpenCL.so: libOpenCL.so.1.0
	ln -sf $< $@

test_tools: libdummycl.so.1.0 ocl_icd_dummy_test

ocl_icd_dummy.o: CFLAGS+= -fpic
libdummycl.so.1.0: ocl_icd_dummy.o
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o $@ \
		-Wl,-Bsymbolic -Wl,-soname,libdummycl.so.1 \
		$(filter %.o,$^) $(LIBS)

ocl_icd_dummy_test: LIBS+= -lOpenCL

ocl_icd_dummy_test.c: stamp-generator-dummy
ocl_icd_dummy.c: stamp-generator-dummy
ocl_icd_dummy.h: stamp-generator-dummy
ocl_icd_h_dummy.h: stamp-generator-dummy
ocl_icd.h: stamp-generator
ocl_icd_lib.c: stamp-generator
ocl_icd_bindings.c: stamp-generator

ICD_GENERATOR_MODE_DATABASE=--database
ICD_GENERATOR_MODE_GENERATOR=--finalize
ICD_GENERATOR_MODE_=$(error No MODE specified!)
stamp-generator: icd_generator.rb
	$(RUBY) icd_generator.rb $(ICD_GENERATOR_MODE_$(MODE))
	touch $@

stamp-generator-dummy: icd_generator.rb
	$(RUBY) icd_generator.rb --generate
	touch $@

.PHONY: install_test_lib uninstall_test_lib
install_test_lib: libdummycl.so.1.0
	cp libdummycl.so.1.0 /usr/local/lib/
	ln -sf libdummycl.so.1.0 /usr/local/lib/libdummycl.so
	ln -sf libdummycl.so.1.0 /usr/local/lib/libdummycl.so.1
	echo "/usr/local/lib/libdummycl.so" > /etc/OpenCL/vendors/dummycl.icd
	ldconfig

uninstall_test_lib:
	rm -f /usr/local/lib/libdummycl.so /usr/local/lib/libdummycl.so.1 /etc/OpenCL/vendors/dummycl.icd

.PHONY: distclean clean partial-clean
distclean:: clean

clean:: partial-clean
	$(RM) *.o ocl_icd_bindings.c ocl_icd.h ocl_icd_lib.c ocl_icd_test ocl_icd_dummy_test libOpenCL.so.1.0 libOpenCL.so stamp-generator

partial-clean::
	$(RM) ocl_icd_dummy_test.o ocl_icd_dummy_test.c ocl_icd_dummy.o ocl_icd_dummy.c ocl_icd_dummy.h ocl_icd_h_dummy.h libdummycl.so.1.0 stamp-generator-dummy

.PHONY: install
install: all
	install -m 755 -d $(DESTDIR)$(libdir)
	install -m 644 libOpenCL.so.1.0 $(DESTDIR)$(libdir)
	ln -s libOpenCL.so.1.0 $(DESTDIR)$(libdir)/libOpenCL.so
