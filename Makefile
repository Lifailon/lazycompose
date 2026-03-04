BIN_NAME = lazycompose
BIN_PATH = $(HOME)/.local/bin

dependencies:
	@-sudo apt update
	@-sudo apt install -y fzf jq micro docker-cli docker-compose tailspin
	@-sudo snap install yq

install: dependencies
	install -D -m 755 $(BIN_NAME) $(BIN_PATH)/$(BIN_NAME)

uninstall:
	rm -f $(BIN_PATH)/$(BIN_NAME)