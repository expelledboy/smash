.PHONY: docker-build on-tag publish

REGISTRY ?= docker.io
USERNAME ?= expelledboy
NAME = $(shell basename $(CURDIR))
IMAGE = $(REGISTRY)/$(USERNAME)/$(NAME)

help: ## Prints help for targets with comments
	@cat $(MAKEFILE_LIST) \
		| grep -E '^[a-zA-Z_-]+:.*?## .*$$' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

docker-build: ## Builds latest docker image
	docker build --tag smash/smash:latest .

on-tag:
	@git describe --exact-match --tags $$(git log -n1 --pretty='%h')

publish: VERSION = $(shell git describe --always | tr -d v)
publish: MINOR = $(shell echo $(VERSION) | sed -n 's/^\(.\..\).*/\1/p')
publish: on-tag docker-build ## Push docker image to $(REGISTRY)
	echo docker tag $(IMAGE):latest $(IMAGE):$(VERSION)
	echo docker tag $(IMAGE):latest $(IMAGE):$(MINOR)
	echo docker push $(IMAGE):$(VERSION)
	echo docker push $(IMAGE):$(MINOR)
	echo docker rmi $(IMAGE):$(VERSION)
	echo docker rmi $(IMAGE):$(MINOR)
	echo docker push $(IMAGE):latest
