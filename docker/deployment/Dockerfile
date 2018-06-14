FROM golang:alpine
MAINTAINER "Nicholas Long<nicholas.long@nrel.gov>"

# This dockerfile is used to build the AMIs. This includes docker, packer, and python.
# To build the AMI run the following:
#
# docker build -t packer .
# docker run -it -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/go/run packer /bin/bash -c 'cd /go/run/docker/deployment; python build_deploy_ami.py --verbose'
#

ENV PACKER_DEV=1

RUN apk add --update git bash openssl python3 docker
RUN go get github.com/mitchellh/gox
RUN go get github.com/hashicorp/packer

WORKDIR $GOPATH/src/github.com/hashicorp/packer

RUN /bin/bash scripts/build.sh

# update python links
RUN ln -s /usr/bin/python3 /usr/bin/python \
    && ln -s /usr/bin/pip3 /usr/bin/pip

WORKDIR $GOPATH

ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt
CMD /bin/bash
