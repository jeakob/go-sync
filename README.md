# Brave Sync Server v2

A sync server implemented in go to communicate with Brave sync clients using
[components/sync/protocol/sync.proto](https://cs.chromium.org/chromium/src/components/sync/protocol/sync.proto).
Current Chromium version for sync protocol buffer files used in this repo is Chromium 116.0.5845.183.

This server supports endpoints as bellow.
- The `POST /v2/command/` endpoint handles Commit and GetUpdates requests from sync clients and return corresponding responses both in protobuf format. Detailed of requests and their corresponding responses are defined in `schema/protobuf/sync_pb/sync.proto`. Sync clients are responsible for generating valid access tokens and present them to the server in the Authorization header of requests.

Currently we use dynamoDB as the datastore, the schema could be found in `schema/dynamodb/table.json`.

## Developer Setup
1. [Install Go 1.22](https://golang.org/doc/install)
2. [Install GolangCI-Lint](https://github.com/golangci/golangci-lint#install)
3. [Install gowrap](https://github.com/hexdigest/gowrap#installation)
4. Clone this repo
5. [Install protobuf protocol compiler](https://github.com/protocolbuffers/protobuf#protocol-compiler-installation) if you need to compile protobuf files, which could be built using `make protobuf`.
6. Build via `make`

## Local development using Docker and DynamoDB Local
1. Clone this repo
2. Run `make docker`
3. Run `make docker-up`
4. To connect to your local server from a Brave browser client use `--sync-url="http://localhost:8295/v2"`
5. For running unit tests, run `make docker-test`

## Deploying a pre-built image

Pre-built images are published to the GitHub Container Registry on every push to `master` and support `linux/amd64` and `linux/arm64`.

| Image | Tag | Platform |
|-------|-----|----------|
| `ghcr.io/jeakob/go-sync` | `latest` | amd64, arm64 |
| `ghcr.io/jeakob/go-sync-dynamo` | `latest` | amd64 |
| `ghcr.io/jeakob/go-sync-dynamo` | `latest-rpi` | arm64 (Raspberry Pi 4) |

amazon/dynamodb-local is based on Amazon Linux 2023 which requires ARMv8.2-a+, but the Raspberry Pi 4's Cortex-A72 is only ARMv8.0-a — so it will never run that image.

### x86 / standard arm64

```bash
docker compose -f docker-compose.yml up
```

### Raspberry Pi 4

```bash
docker compose -f docker-compose.rpi.yml up
```

> Data is persisted across restarts in `./data/dynamo` and `./data/redis`.

### Pointing Brave at your server

**Via flags UI:** Open `brave://flags`, search for `brave-override-sync-server-url`, enter your server URL and restart.

**Via command line:**
```bash
# Linux
brave-browser --sync-url="http://<your-server-ip>:8295/v2"

# macOS
/Applications/Brave\ Browser.app/Contents/MacOS/Brave\ Browser --sync-url="http://<your-server-ip>:8295/v2"

# Windows
"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe" --sync-url="http://<your-server-ip>:8295/v2"
```

**Linux persistent flag** (add to `~/.config/brave-flags.conf`):
```
--sync-url=http://<your-server-ip>:8295/v2
```

Verify the server is being used at `brave://sync-internals`.

# Updating protocol definitions
1. Copy the `.proto` files from `components/sync/protocol` in `chromium` to `schema/protobuf/sync_pb` in `go-sync`.
2. Copy the `.proto` files from `components/sync/protocol` in `brave-core` to `schema/protobuf/sync_pb` in `go-sync`.
3. Run `make repath-proto` to set correct import paths in `.proto` files.
4. Run `make proto-go-module` to add the `go_module` option to `.proto` files.
5. Run `make protobuf` to generate the Go code from `.proto` definitions.

## Prometheus Instrumentation
The instrumented datastore and redis interfaces are generated, providing integration with Prometheus. The following will re-generate the instrumented code, required when updating protocol definitions:

```bash
make instrumented
```

Changes to `datastore/datastore.go` or `cache/cache.go` should be followed with the above command.
