

VERSION=$(shell ruby -r './lib/bolt/version' -e "puts Bolt::VERSION")
TARGET=bolt
TMPDIR=`mktemp -d`
PLATFORM=$(shell uname | awk '{print tolower($$0)}')

#TODO make this work on Windows (cleanly)

all: $(TARGET)

fat-binary: $(TARGET)

$(TARGET):
	rubyc -d $(TMPDIR) -o $(TARGET)-$(VERSION) -c --auto-update-url=http://updates.puppet.com/$(TARGET)/$(PLATFORM) --auto-update-base=$(VERSION)  exe/$(TARGET)

clean:
	rm -rf $(TARGET)-* /tmp/rubyc ~/.libautoupdate $(TARGET)
