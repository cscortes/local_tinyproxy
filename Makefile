.PHONY: info build run serve start server bserve bstart bserver test scan stop

PORT=8080
SVRHOST=127.0.0.1
PROJECT_DIR=$(shell pwd)
CURRENTUSER=$(shell whoami)

CONTAINER_LIST=docker container list --filter "name=local-proxy"
DOCKER_LIST=docker images --filter "reference=local-proxy-img"

info:
	@echo "===================================================================="
	@echo "Container:"
	@$(CONTAINER_LIST) | grep local-proxy || echo "No container Found!"
	@echo "-------------------------------------------------------------------"
	@echo "Images:"
	@$(DOCKER_LIST) | grep local-proxy-img || echo "No image Found!"
	@echo "===================================================================="

build: docker-compose.yaml
	@echo "Building the image ..."
	docker compose build

#Forground server
serve start server: build
	@echo "Running the image in Forground"
	docker compose up

#Forground server
bserve bstart bserver: build
	@echo "Running the image in background"
	docker compose up -d

run:
	docker compose run -i cache-tinyproxy bash

runx:
	docker compose exec -i cache-tinyproxy bash

stop:
	@echo "Stopping container ..."
	docker compose down

test_http:
	@echo "HTTP TEST: tinyproxy server ..."
	curl -x "http://$(SVRHOST):$(PORT)" "http://google.com"
	@echo $@

test: test_http
	@echo "HTTPS TEST: tinyproxy server ..."
	curl -x "http://$(SVRHOST):$(PORT)" "https://google.com"
	@echo $@

scan:
	@echo "Scanning for tinyproxy server with nmap ..."
	nmap $(SVRHOST) -p 8000-9000 | grep $(PORT)

clean: stop
	@$(CONTAINER_LIST) -q | xargs -r docker rm -fv
	@$(DOCKER_LIST) -q | xargs -r docker rmi

create_scripts:
	echo -e '#!/bin/bash\n' > fedora/start.sh
	echo -e "cd $(PROJECT_DIR) && make server\n" >> fedora/start.sh
	echo -e '#!/bin/bash\n' > fedora/stop.sh
	echo -e "cd $(PROJECT_DIR) && make stop\n" >> fedora/stop.sh
	chmod 777 fedora/*.sh
	sudo mv -f fedora/*.sh /usr/local/bin/
	sudo restorecon -F -R /usr/local/bin/start.sh
	sudo restorecon -F -R /usr/local/bin/stop.sh

# this deploy is fedora specific
deploy: create_scripts
	sed 's/USER/$(CURRENTUSER)/g' ./fedora/docker-tinyproxy.service.template > ./fedora/docker-tinyproxy.service
	chmod 644 fedora/*.service
	sudo chown root:root fedora/*.service
	sudo mv -f fedora/*.service /etc/systemd/system
	sudo /sbin/restorecon -v /etc/systemd/system/docker-tinyproxy.service
	sudo systemctl enable docker-tinyproxy
	sudo systemctl start docker-tinyproxy
	sudo firewall-cmd --permanent --add-port 8080/tcp
	sudo firewall-cmd --reload

