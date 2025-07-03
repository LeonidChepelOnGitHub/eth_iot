FROM golang:1.20-alpine AS builder

RUN apk add --no-cache make gcc musl-dev linux-headers git

WORKDIR /app

COPY go-ethereum .

RUN make all

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/build/bin/geth /usr/local/bin/
COPY --from=builder /app/build/bin/bootnode /usr/local/bin/

EXPOSE 8545 8546 30303 30303/udp

CMD ["geth"]