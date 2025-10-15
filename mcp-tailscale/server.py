#!/usr/bin/env python3
import json
import asyncio
import subprocess
from mcp.server import Server
from mcp.types import Tool, TextContent
import mcp.server.stdio

app = Server("tailscale-mcp")

def load_config():
    with open("config.json", "r") as f:
        return json.load(f)

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="list_devices",
            description="List all devices in the tailnet",
            inputSchema={"type": "object", "properties": {}}
        ),
        Tool(
            name="device_status",
            description="Get status of a specific device",
            inputSchema={
                "type": "object",
                "properties": {"device": {"type": "string"}},
                "required": ["device"]
            }
        ),
        Tool(
            name="enable_exit_node",
            description="Enable exit node on current device",
            inputSchema={"type": "object", "properties": {}}
        ),
        Tool(
            name="list_exit_nodes",
            description="List all active exit nodes in the tailnet",
            inputSchema={"type": "object", "properties": {}}
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    config = load_config()
    
    if name == "list_devices":
        result = subprocess.run(["tailscale", "status", "--json"], capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            devices = [f"{peer['HostName']} ({peer['TailscaleIPs'][0]})" 
                      for peer in data.get('Peer', {}).values()]
            return [TextContent(type="text", text=f"Devices:\n" + "\n".join(devices))]
        return [TextContent(type="text", text="Failed to list devices")]
    
    elif name == "device_status":
        device = arguments["device"]
        result = subprocess.run(["tailscale", "ping", device], capture_output=True, text=True)
        status = "online" if result.returncode == 0 else "offline"
        return [TextContent(type="text", text=f"Device {device} is {status}")]
    
    elif name == "enable_exit_node":
        result = subprocess.run(["tailscale", "up", "--advertise-exit-node"], capture_output=True, text=True)
        if result.returncode == 0:
            return [TextContent(type="text", text="Exit node enabled successfully")]
        return [TextContent(type="text", text="Failed to enable exit node")]
    
    elif name == "list_exit_nodes":
        result = subprocess.run(["tailscale", "status", "--json"], capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            exit_nodes = [f"{peer['HostName']} ({peer['TailscaleIPs'][0]})" 
                         for peer in data.get('Peer', {}).values() 
                         if peer.get('ExitNode', False)]
            if exit_nodes:
                return [TextContent(type="text", text=f"Active exit nodes:\n" + "\n".join(exit_nodes))]
            return [TextContent(type="text", text="No active exit nodes found")]
        return [TextContent(type="text", text="Failed to list exit nodes")]

async def main():
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())