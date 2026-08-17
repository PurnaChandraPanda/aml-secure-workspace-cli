"""
MCP Route - Step 3: Run the KB-MCP agent.

Because the MCP tool executes server-side (Foundry -> KB), this runner is a
simple single streaming call -- no client-side function-call loop and no direct
access to the private Search endpoint. Citations arrive as response annotations.
"""
import base64
import os
import re
import sys
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
from azure.ai.projects import AIProjectClient

load_dotenv()

sys.stdout.reconfigure(encoding="utf-8")  # print citation glyphs on Windows

PROJECT_ENDPOINT = os.getenv("PROJECT_ENDPOINT")
AGENT_NAME = "v2agent-rag-kbmcp-001"
AGENT_VERSION = "1"  # set to the version printed by create-kb-mcp-agent.py

# The KB MCP tool returns citations as opaque reference ids shaped like:
#   mcp://searchindex/<indexPrefix>_<base64url(source_url)>_pages_<n>
# The document key (base64url of the original source_url) is embedded in the
# middle. This regex peels off the known prefix/suffix so we can decode it back
# to the real blob URL and page number.
_MCP_REF_RE = re.compile(r"^mcp://searchindex/[0-9a-fA-F]+_(?P<b64>.+)_pages_(?P<page>\d+)$")


def decode_mcp_citation(ref: str):
    """Return (source_url, page) from an mcp://searchindex/... reference id.

    Falls back to (None, None) if the string isn't in the expected shape or the
    embedded segment doesn't base64url-decode to an http(s) URL.
    """
    if not ref:
        return None, None
    match = _MCP_REF_RE.match(ref)
    if not match:
        return None, None
    b64 = match.group("b64")
    b64 += "=" * (-len(b64) % 4)  # restore stripped base64 padding
    try:
        decoded = base64.urlsafe_b64decode(b64.encode()).decode("utf-8", "replace")
    except Exception:
        return None, None
    decoded = decoded.rstrip("\r\n\t ")  # Search key encoding can leave a trailing control byte
    if not decoded.startswith(("http://", "https://")):
        return None, None
    return decoded, match.group("page")


project_client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
openai_client = project_client.get_openai_client()


def main(user_input: str):
    conversation = openai_client.conversations.create()
    print(f"Created conversation (id: {conversation.id})")

    stream = openai_client.responses.create(
        stream=True,
        input=user_input,
        conversation=conversation.id,
        extra_body={"agent_reference": {"name": AGENT_NAME, "version": AGENT_VERSION, "type": "agent_reference"}},
    )

    for event in stream:
        if event.type == "response.output_text.delta":
            print(event.delta, end="", flush=True)
        elif event.type == "response.output_item.done":
            item = event.item
            if item.type == "message" and item.content and item.content[-1].type == "output_text":
                for annotation in item.content[-1].annotations or []:
                    if annotation.type == "url_citation":
                        raw = getattr(annotation, "url", None)
                        title = getattr(annotation, "title", None)
                        source_url, page = decode_mcp_citation(raw)
                        if source_url:
                            page_str = f" (page {page})" if page is not None else ""
                            print(f"\nURL Citation: {source_url}{page_str}")
                        else:
                            print(f"\nURL Citation: {raw}, title: {title}")
                    else:
                        print("\nannotation:", annotation)
        elif event.type == "response.completed":
            print("\n[done]")
            print("Agent response:\n", event.response.output_text)


if __name__ == "__main__":
    main("what is the NASA earth book about")
