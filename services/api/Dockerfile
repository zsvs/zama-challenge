# --- build stage ---
FROM golang:1.25.3-alpine3.21 AS build
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/api

# --- runtime stage ---
FROM gcr.io/distroless/static:nonroot
WORKDIR /
USER nonroot:nonroot
COPY --from=build /out/api /api
EXPOSE 8080
ENTRYPOINT ["/api"]
