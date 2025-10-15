# Tailscale MCP Server

Minimal MCP server for Tailscale management that can be dockerized.

## Features

- List devices in tailnet
- Check device status
- Enable exit node
- List active exit nodes

## Setup

1. Copy `.env.example` to `.env` and set your Tailscale auth key
2. Run with Docker Compose:

```bash
docker-compose up -d
```

## Usage

The server provides four tools:
- `list_devices`: Shows all devices in your tailnet
- `device_status`: Check if a device is online/offline
- `enable_exit_node`: Enable exit node on current device
- `list_exit_nodes`: Shows all active exit nodes in the tailnet