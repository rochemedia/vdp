.DEFAULT_GOAL:=help

#============================================================================

# load environment variables
include .env
export

UNAME_S := $(shell uname -s)

CONTAINER_BUILD_NAME := vdp-build
CONTAINER_COMPOSE_IMAGE_NAME := instill/vdp-compose
CONTAINER_PLAYWRIGHT_IMAGE_NAME := instill/vdp-console-playwright
CONTAINER_BACKEND_INTEGRATION_TEST_NAME := vdp-backend-integration-test
CONTAINER_CONSOLE_INTEGRATION_TEST_NAME := vdp-console-integration-test

BASE_DOCKER_COMPOSE_NAME := base-dind
MODEL_DOCKER_COMPOSE_NAME := model-dind

HELM_NAMESPACE := instill-ai
HELM_RELEASE_NAME := vdp

#============================================================================

.PHONY: all
all:			## Launch all services with their up-to-date release version
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${BASE_DOCKER_COMPOSE_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			cp -r /instill-ai/base/configs/* $${TMP_CONFIG_DIR} && \
			/bin/bash -c 'cd /instill-ai/base && make all EDITION=local-ce OBSERVE_ENABLED=${OBSERVE_ENABLED} OBSERVE_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' \
		" && rm -r $${TMP_CONFIG_DIR}
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name ${MODEL_DOCKER_COMPOSE_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd /instill-ai/model && make all EDITION=local-ce' \
		"
	@EDITION=local-ce docker compose -f docker-compose.yml up -d --quiet-pull
	@EDITION=local-ce docker compose -f docker-compose.yml rm -f

.PHONY: latest
latest:			## Lunch all dependent services with their latest codebase
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${BASE_DOCKER_COMPOSE_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			cp -r /instill-ai/base/configs/* $${TMP_CONFIG_DIR} && \
			/bin/bash -c 'cd /instill-ai/base && make latest PROFILE=$(PROFILE) EDITION=local-ce:latest OBSERVE_ENABLED=${OBSERVE_ENABLED} OBSERVE_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' \
		" && rm -r $${TMP_CONFIG_DIR}
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name ${MODEL_DOCKER_COMPOSE_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd /instill-ai/model && make latest PROFILE=$(PROFILE) EDITION=local-ce:latest' \
		"
	@COMPOSE_PROFILES=$(PROFILE) EDITION=local-ce:latest docker compose -f docker-compose.yml -f docker-compose.latest.yml up -d --quiet-pull
	@COMPOSE_PROFILES=$(PROFILE) EDITION=local-ce:latest docker compose -f docker-compose.yml -f docker-compose.latest.yml rm -f

.PHONY: logs
logs:			## Tail all logs with -n 10
	@docker compose logs --follow --tail=10

.PHONY: pull
pull:			## Pull all service images
	@docker compose pull

.PHONY: stop
stop:			## Stop all components
	@docker compose stop

.PHONY: start
start:			## Start all stopped services
	@docker compose start

.PHONY: restart
restart:		## Restart all services
	@docker compose restart

.PHONY: rm
rm:				## Remove all stopped service containers
	@docker compose rm -f

.PHONY: down
down:			## Stop all services and remove all service containers and volumes
	@docker rm -f ${CONTAINER_BUILD_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BUILD_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-helm-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-helm-release >/dev/null 2>&1
	@docker compose -f docker-compose.yml -f docker-compose.observe.yml down -v
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name ${MODEL_DOCKER_COMPOSE_NAME} \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd /instill-ai/model && make down' \
		"
	@docker rm -f ${MODEL_DOCKER_COMPOSE_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${MODEL_DOCKER_COMPOSE_NAME}-release >/dev/null 2>&1
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name ${BASE_DOCKER_COMPOSE_NAME} \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd /instill-ai/base && make down' \
		"
	@docker rm -f ${BASE_DOCKER_COMPOSE_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${BASE_DOCKER_COMPOSE_NAME}-release >/dev/null 2>&1

.PHONY: images
images:			## List all container images
	@docker compose images

.PHONY: ps
ps:				## List all service containers
	@docker compose ps

.PHONY: top
top:			## Display all running service processes
	@docker compose top

.PHONY: doc
doc:						## Run Redoc for OpenAPI spec at http://localhost:3001
	@docker compose up -d redoc_openapi

.PHONY: build-latest
build-latest:				## Build latest images for all VDP components
	@docker build --progress plain \
		--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
		--build-arg GOLANG_VERSION=${GOLANG_VERSION} \
		--build-arg K6_VERSION=${K6_VERSION} \
		--build-arg CACHE_DATE="$(shell date)" \
		--target latest \
		-t ${CONTAINER_COMPOSE_IMAGE_NAME}:latest .
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}/.env:/instill-ai/vdp/.env \
		-v ${PWD}/docker-compose.build.yml:/instill-ai/vdp/docker-compose.build.yml \
		--name ${CONTAINER_BUILD_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			API_GATEWAY_VERSION=latest \
			PIPELINE_BACKEND_VERSION=latest \
			CONNECTOR_BACKEND_VERSION=latest \
			CONTROLLER_VDP_VERSION=latest \
			docker compose -f docker-compose.build.yml build --progress plain \
		"

.PHONY: build-release
build-release:				## Build release images for all VDP components
	@docker build --progress plain \
		--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
		--build-arg GOLANG_VERSION=${GOLANG_VERSION} \
		--build-arg K6_VERSION=${K6_VERSION} \
		--build-arg CACHE_DATE="$(shell date)" \
		--build-arg API_GATEWAY_VERSION=${API_GATEWAY_VERSION} \
		--build-arg PIPELINE_BACKEND_VERSION=${PIPELINE_BACKEND_VERSION} \
		--build-arg CONNECTOR_BACKEND_VERSION=${CONNECTOR_BACKEND_VERSION} \
		--build-arg CONTROLLER_VDP_VERSION=${CONTROLLER_VDP_VERSION} \
		--target release \
		-t ${CONTAINER_COMPOSE_IMAGE_NAME}:release .
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}/.env:/instill-ai/vdp/.env \
		-v ${PWD}/docker-compose.build.yml:/instill-ai/vdp/docker-compose.build.yml \
		--name ${CONTAINER_BUILD_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			API_GATEWAY_VERSION=${API_GATEWAY_VERSION} \
			PIPELINE_BACKEND_VERSION=${PIPELINE_BACKEND_VERSION} \
			CONNECTOR_BACKEND_VERSION=${CONNECTOR_BACKEND_VERSION} \
			CONTROLLER_VDP_VERSION=${CONTROLLER_VDP_VERSION} \
			docker compose -f docker-compose.build.yml build --progress plain \
		"

.PHONY: integration-test-latest
integration-test-latest:			## Run integration test on the latest VDP
	@make build-latest
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${BASE_DOCKER_COMPOSE_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			cp /instill-ai/base/.env $${TMP_CONFIG_DIR}/.env && \
			cp /instill-ai/base/docker-compose.build.yml $${TMP_CONFIG_DIR}/docker-compose.build.yml && \
			/bin/bash -c 'cd /instill-ai/base && make build-latest BUILD_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' && \
			/bin/bash -c 'cd /instill-ai/base && make latest PROFILE=all EDITION=local-ce:test' \
		" && rm -r $${TMP_CONFIG_DIR}
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${MODEL_DOCKER_COMPOSE_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			cp /instill-ai/model/.env $${TMP_CONFIG_DIR}/.env && \
			cp /instill-ai/model/docker-compose.build.yml $${TMP_CONFIG_DIR}/docker-compose.build.yml && \
			/bin/bash -c 'cd /instill-ai/model && make build-latest BUILD_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' && \
			/bin/bash -c 'cd /instill-ai/model && make latest PROFILE=all ITMODE_ENABLED=true EDITION=local-ce:test' \
		" && rm -r $${TMP_CONFIG_DIR}
	@COMPOSE_PROFILES=all EDITION=local-ce:test docker compose -f docker-compose.yml -f docker-compose.latest.yml up -d --quiet-pull
	@COMPOSE_PROFILES=all EDITION=local-ce:test docker compose -f docker-compose.yml -f docker-compose.latest.yml rm -f
	@docker run -it --rm \
		--network instill-network \
		--name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd connector-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@make down

.PHONY: integration-test-release
integration-test-release:			## Run integration test on the release VDP
	@make build-release
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${BASE_DOCKER_COMPOSE_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			cp /instill-ai/base/.env $${TMP_CONFIG_DIR}/.env && \
			cp /instill-ai/base/docker-compose.build.yml $${TMP_CONFIG_DIR}/docker-compose.build.yml && \
			/bin/bash -c 'cd /instill-ai/base && make build-release BUILD_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' && \
			/bin/bash -c 'cd /instill-ai/base && make all EDITION=local-ce:test' \
		" && rm -r $${TMP_CONFIG_DIR}
	@export TMP_CONFIG_DIR=$(shell mktemp -d) && docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $${TMP_CONFIG_DIR}:$${TMP_CONFIG_DIR} \
		--name ${MODEL_DOCKER_COMPOSE_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			cp /instill-ai/model/.env $${TMP_CONFIG_DIR}/.env && \
			cp /instill-ai/model/docker-compose.build.yml $${TMP_CONFIG_DIR}/docker-compose.build.yml && \
			/bin/bash -c 'cd /instill-ai/model && make build-release BUILD_CONFIG_DIR_PATH=$${TMP_CONFIG_DIR}' && \
			/bin/bash -c 'cd /instill-ai/model && make all ITMODE_ENABLED=true EDITION=local-ce:test' \
		" && rm -r $${TMP_CONFIG_DIR}
	@EDITION=local-ce:test ITMODE_ENABLED=true docker compose up -d --quiet-pull
	@EDITION=local-ce:test docker compose rm -f
	@docker run -it --rm \
		--network instill-network \
		--name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c cd connector-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT} && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST}API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@make down

.PHONY: helm-integration-test-latest
helm-integration-test-latest:                       ## Run integration test on the Helm latest for VDP
ifeq ($(UNAME_S),Darwin)
	@make build-latest
	@helm install vdp charts/vdp --devel --namespace vdp --create-namespace \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set pipeline.image.tag=latest \
		--set connector.image.tag=latest \
		--set controller.image.tag=latest \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT} \
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm -p ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest ${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd connector-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall vdp --namespace vdp
	@kubectl delete namespace vdp
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-latest
	@helm install vdp charts/vdp --devel --namespace vdp --create-namespace \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set pipeline.image.tag=latest \
		--set connector.image.tag=latest \
		--set controller.image.tag=latest \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT} \
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm --network host --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest ${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd connector-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall vdp --namespace vdp
	@kubectl delete namespace vdp
	@pkill -f "port-forward"
	@make down
endif

.PHONY: helm-integration-test-release
helm-integration-test-release:                       ## Run integration test on the Helm release for VDP
ifeq ($(UNAME_S),Darwin)
	@make build-release
	@helm install vdp charts/vdp --devel --namespace vdp --create-namespace \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set pipeline.image.tag=${PIPELINE_BACKEND_VERSION} \
		--set connector.image.tag=${CONNECTOR_BACKEND_VERSION} \
		--set controller.image.tag=${CONTROLLER_VDP_VERSION} \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT} \
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm -p ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release ${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd connector-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall vdp --namespace vdp
	@kubectl delete namespace vdp
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-release
	@helm install vdp charts/vdp --devel --namespace vdp --create-namespace \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set pipeline.image.tag=${PIPELINE_BACKEND_VERSION} \
		--set connector.image.tag=${CONNECTOR_BACKEND_VERSION} \
		--set controller.image.tag=${CONTROLLER_VDP_VERSION} \
		--set console.image.tag=${CONSOLE_VERSION} \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT} \
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm --network host --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release ${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd pipeline-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd connector-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' && \
			/bin/bash -c 'cd controller-vdp && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall vdp --namespace vdp
	@kubectl delete namespace vdp
	@pkill -f "port-forward"
	@make down
endif

.PHONY: help
help:       	## Show this help
	@echo "\nMake Application with Docker Compose"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
