NAME = alburena/docker-openldap
VERSION = 1.0.0

.PHONY: build clean run up down test help

build:
	docker build -t $(NAME):$(VERSION) .

tag:
	docker tag $(NAME):$(VERSION) $(NAME):$(VERSION)

tag-latest:
	docker tag $(NAME):$(VERSION) $(NAME):latest

push:
	docker push $(NAME):$(VERSION)

push-latest:
	docker push $(NAME):latest

release: build tag-latest push push-latest

clean:
	docker rm -f openldap; true

run: build clean
	docker run -it -d --name openldap -p 389:389 -p 636:636 -p 8100:80 -v config.php:/etc/phpldapadmin/config.php --hostname ldap.mesesale.local $(NAME):$(VERSION) sh

up: build clean
	docker-compose -f ./examples/docker-compose.yml up
	
help:
	@echo "Usage: make build|clean|run|up|down|test"