SCRIPT_DIR = src/IDM/endpoint
TARGET_DIR = target
ENDPOINT = chat-token

default:
	mkdir -p $(TARGET_DIR)
	sed  's/\/\/.*//; s/^ *//g; s/\\/\\\\/g; s/"/\\"/g' $(SCRIPT_DIR)/$(ENDPOINT).js | tr -d '\n\r' | sed 's/\(.*\)/{"type": "text\/javascript","source":"\1"}/' > $(TARGET_DIR)/endpoint-$(ENDPOINT).json

install:
	utils/install.sh conf/tenant.properties $(TARGET_DIR)/endpoint-$(ENDPOINT).json $(ENDPOINT)

clean:
	rm -rf $(TARGET_DIR)
