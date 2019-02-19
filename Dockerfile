FROM golang:1.11.0-alpine as builder

RUN go version

RUN set -x && \
    apk add unzip curl git make libc6-compat && \
    go get github.com/golang/dep/cmd/dep

COPY . /go/src/
WORKDIR /go/src/
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 make

FROM alpine:3.7
WORKDIR /root/
COPY --from=builder /go/src/main .

EXPOSE 8080
ENTRYPOINT ["./main"]
