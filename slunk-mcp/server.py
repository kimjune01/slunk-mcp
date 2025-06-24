from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("slunk")


@mcp.tool()
async def ping_slunk() -> str:
    """Ping the slunk server"""
    return "Pong slunk!"


if __name__ == "__main__":
    mcp.run()
