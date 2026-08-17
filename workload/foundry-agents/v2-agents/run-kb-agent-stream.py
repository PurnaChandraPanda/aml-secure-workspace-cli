"""
Route B - Step 3: Run the KB-backed agent, fulfilling its function calls by
querying the Azure AI Search Knowledge Base.

Flow (OpenAI responses function-calling loop):
  1. Ask the agent (streaming). The agent emits a `function_call` for
     search_knowledge_base.
  2. We call the Knowledge Base retrieval client, format passages + source_url
     references, and return them as `function_call_output`.
  3. The agent streams the final grounded answer with citations.

NETWORK: the KB retrieval client hits the private Search endpoint (10.0.0.13),
so run this from inside the vnet.
"""
import os
import json
import sys

from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.search.documents.knowledgebases import KnowledgeBaseRetrievalClient
from azure.search.documents.knowledgebases.models import (
    KnowledgeBaseRetrievalRequest,
    KnowledgeRetrievalSemanticIntent,
    KnowledgeSourceParams,
)

sys.stdout.reconfigure(encoding="utf-8")  # print citation glyphs on Windows

# Foundry project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"

# Created foundry prompt agent name, version details
AGENT_NAME = "v2agent-rag-kb-001"
AGENT_VERSION = "1"

# Azure Search service endpoint and Knowledge Base, Source details
AZURE_SEARCH_SERVICE = "https://aifoundry3738search.search.windows.net"
KNOWLEDGE_BASE_NAME = "py-citation-kb"
KNOWLEDGE_SOURCE_NAME = "py-citation-ks"
TOP_K_REFERENCES = 5  # cap citations passed to the model / printed

credential = DefaultAzureCredential()
project_client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential)
openai_client = project_client.get_openai_client()

kb_client = KnowledgeBaseRetrievalClient(
    endpoint=AZURE_SEARCH_SERVICE,
    credential=credential,
    knowledge_base_name=KNOWLEDGE_BASE_NAME,
)


def query_knowledge_base(query: str) -> str:
    """Call the KB and return a JSON string of passages + citations."""
    request = KnowledgeBaseRetrievalRequest(
        intents=[KnowledgeRetrievalSemanticIntent(search=query)],
        include_activity=True,
        knowledge_source_params=[
            KnowledgeSourceParams(
                knowledge_source_name=KNOWLEDGE_SOURCE_NAME,
                kind="searchIndex",
                include_references=True,
                include_reference_source_data=True,
            )
        ],
    )
    result = kb_client.retrieve(request)

    # Flatten the KB text response.
    text_parts = []
    for msg in result.response or []:
        for content in msg.content or []:
            text = getattr(content, "text", None)
            if text:
                text_parts.append(text)

    # Extract citations from each reference's source_data.
    citations = []
    for ref in result.references or []:
        data = getattr(ref, "source_data", None) or {}
        citations.append(
            {
                "source_url": data.get("source_url"),
                "source_file_name": data.get("source_file_name"),
                "title": data.get("title"),
                "doc_key": getattr(ref, "doc_key", None),
                "reranker_score": getattr(ref, "reranker_score", None),
            }
        )

    # Rank by reranker score (desc), drop duplicate URLs, keep the top K.
    citations.sort(key=lambda c: c["reranker_score"] or 0, reverse=True)
    seen, top_citations = set(), []
    for c in citations:
        if c["source_url"] in seen:
            continue
        seen.add(c["source_url"])
        top_citations.append(c)
        if len(top_citations) >= TOP_K_REFERENCES:
            break

    print(f"\n[KB references — top {len(top_citations)} of {len(citations)}]")
    for c in top_citations:
        print(f"  - ({c['reranker_score']}) {c['source_file_name']} -> {c['source_url']}")

    return json.dumps({"content": "\n\n".join(text_parts), "citations": top_citations})


def run_turn(user_input: str):
    conversation = openai_client.conversations.create()
    print(f"Created conversation (id: {conversation.id})")

    agent_ref = {"agent_reference": {"name": AGENT_NAME, "version": AGENT_VERSION, "type": "agent_reference"}}

    # First request: the agent decides to call the function.
    stream = openai_client.responses.create(
        stream=True,
        input=user_input,
        conversation=conversation.id,
        tool_choice="auto",
        extra_body=agent_ref,
    )

    while True:
        pending_calls = []  # list of (call_id, name, arguments)

        for event in stream:
            if event.type == "response.output_text.delta":
                print(event.delta, end="", flush=True)
            elif event.type == "response.output_item.done":
                item = event.item
                if item.type == "function_call":
                    pending_calls.append((item.call_id, item.name, item.arguments))

        if not pending_calls:
            print("\n[done]")
            break

        # Fulfil each function call and submit outputs on the next turn.
        tool_outputs = []
        for call_id, name, arguments in pending_calls:
            args = json.loads(arguments) if arguments else {}
            if name == "search_knowledge_base":
                output = query_knowledge_base(args.get("query", user_input))
            else:
                output = json.dumps({"error": f"unknown tool {name}"})
            tool_outputs.append({"type": "function_call_output", "call_id": call_id, "output": output})

        stream = openai_client.responses.create(
            stream=True,
            input=tool_outputs,
            conversation=conversation.id,
            tool_choice="auto",
            extra_body=agent_ref,
        )


if __name__ == "__main__":
    run_turn("what is the NASA earth book about")
