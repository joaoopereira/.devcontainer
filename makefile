build-docker:
	docker build . -t joaoopereira/devcontainer:$(TARGET) --target $(TARGET) --platform linux/amd64

build-latest: TARGET=latest
build-latest: build-docker

build: TARGET=next
build: build-docker