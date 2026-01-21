# PHP Extension Makefile for qzoke
# Combines Zig MD5 implementation with PHP Zend API

# PHP configuration
PHP_CONFIG := php-config
PHP_INCLUDE := $(shell $(PHP_CONFIG) --includes)
PHP_EXT_DIR := $(shell $(PHP_CONFIG) --extension-dir)
PHP_VERSION := $(shell $(PHP_CONFIG) --version)

# Compiler settings - use zig cc as C compiler
CC := zig cc
ZIG := zig

# Flags
CFLAGS := -O3 -fPIC -DCOMPILE_DL_QZOKE $(PHP_INCLUDE)
LDFLAGS := -shared -undefined dynamic_lookup

# Output
EXT_NAME := qzoke
OUTPUT := $(EXT_NAME).so

# Platform detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    LDFLAGS := -bundle -undefined dynamic_lookup
    OUTPUT := $(EXT_NAME).so
endif

# Source files
C_SOURCES := qzoke.c
ZIG_SOURCES := md5.zig

# Object files
C_OBJECTS := $(C_SOURCES:.c=.o)
ZIG_OBJECTS := md5.o

.PHONY: all clean install info test

all: $(OUTPUT)

# Build the extension
$(OUTPUT): $(C_OBJECTS) $(ZIG_OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

# Compile C code
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Compile Zig code to object file
md5.o: md5.zig
	$(ZIG) build-obj -OReleaseFast -fPIC -femit-bin=$@ $<

clean:
	rm -f $(OUTPUT) $(C_OBJECTS) $(ZIG_OBJECTS)

install: $(OUTPUT)
	cp $(OUTPUT) $(PHP_EXT_DIR)/
	@echo "Installed to $(PHP_EXT_DIR)/$(OUTPUT)"
	@echo "Add 'extension=$(EXT_NAME)' to your php.ini"

info:
	@echo "PHP Version: $(PHP_VERSION)"
	@echo "PHP Include: $(PHP_INCLUDE)"
	@echo "PHP Extension Dir: $(PHP_EXT_DIR)"
	@echo "Output: $(OUTPUT)"

test: $(OUTPUT)
	php -d "extension=./$(OUTPUT)" -r "echo qzoke_md5('hello') . PHP_EOL;"
	php -d "extension=./$(OUTPUT)" -r "var_dump(qzoke_md5('hello') === md5('hello'));"
