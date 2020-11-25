# BUILD STAGE
FROM golang:1.12.5 as build

WORKDIR /go/src/app

COPY ${PWD} /go/src/app

RUN mkdir -p "/go/src/app/bin/" \
 && CGO_ENABLED=0 GOOS=linux go build -o "bin/myApp" cmd/*.go

# RUNTIME STAGE
FROM alpine:3 as runtime

RUN apk add --no-cache ca-certificates

COPY --from=build /go/src/app/bin/myApp /

USER nobody

CMD ["/myApp"]