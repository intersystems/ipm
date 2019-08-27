
VERSION?=$(shell cat .version)
NAME?=zpm
FULLNAME=$(NAME)-$(VERSION)

IMAGE?=$(NAME):$(VERSION)
BASE?=intersystems/iris:2019.3.0.302.0

build:
	docker build -t $(IMAGE) .

release: clean build
	echo release $(FULLNAME)
	echo image $(IMAGE)
	docker run --rm -it -v `pwd`/scripts:/opt/scripts -v `pwd`/out:/opt/out -w /opt/out --entrypoint /opt/scripts/make-release.sh $(IMAGE) $(FULLNAME).xml $(VERSION)
	make check

clean:
	rm -rf out
check:
	docker run --rm -it -v `pwd`/scripts:/opt/scripts -v `pwd`/out:/opt/out -w /opt/out --entrypoint /opt/scripts/check-release.sh $(BASE) $(FULLNAME).xml

test: build
	docker run --rm -it -v `pwd`/scripts:/opt/scripts --entrypoint /opt/scripts/run-tests.sh $(IMAGE)
	