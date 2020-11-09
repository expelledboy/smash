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
	docker build --tag $(IMAGE):latest .

on-tag:
	git describe --exact-match --tags $$(git log -n1 --pretty='%h') 1>/dev/null

publish: VERSION = $(shell git describe --always --tags | tr -d v)
publish: MINOR = $(shell echo $(VERSION) | sed -n 's/^\(.\..\).*/\1/p')
publish: on-tag docker-build ## Push docker image to $(REGISTRY)
	docker tag $(IMAGE):latest $(IMAGE):$(VERSION)
	docker tag $(IMAGE):latest $(IMAGE):$(MINOR)
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(MINOR)
	docker rmi $(IMAGE):$(VERSION)
	docker rmi $(IMAGE):$(MINOR)
	docker push $(IMAGE):latest
