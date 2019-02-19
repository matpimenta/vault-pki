# Makefile

export GOPATH=

all: deps
		go build -o app

deps:
		dep ensure

run: 
		go run *.go
