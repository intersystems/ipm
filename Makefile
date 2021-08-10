
VERSION?=$(shell sed -n 's|^ *<Version>\(.*\)</Version> *|\1|p' module.xml)
NAME?=zpm
FULLNAME=$(NAME)-$(VERSION)

IMAGE?=$(NAME):$(VERSION)
BASE?=store/intersystems/iris-community:2020.4.0.547.0

build: clean
	docker build -t $(IMAGE) .

release: build
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
	