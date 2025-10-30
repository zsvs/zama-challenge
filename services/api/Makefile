SHELL := /bin/bash

.PHONY: test build run
test:
	go test ./...

build:
	go build -o bin/api

run:
	REQUIRE_API_KEY=false go run main.go
