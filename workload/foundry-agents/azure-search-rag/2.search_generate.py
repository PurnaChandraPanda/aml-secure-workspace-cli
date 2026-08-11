from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from openai import AzureOpenAI

from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

AZURE_SEARCH_SERVICE = os.getenv("AZURE_SEARCH_SERVICE")
AZURE_SEARCH_INDEX = os.getenv("AZURE_SEARCH_INDEX")
AZURE_OPENAI_ACCOUNT = os.getenv("AZURE_OPENAI_ACCOUNT")
index_name = os.getenv("AZURE_SEARCH_INDEX")

credential = DefaultAzureCredential()

def vector_search():
    # Vector Search using text-to-vector conversion of the query string
    query = "what's NASA's website?"  

    search_client = SearchClient(endpoint=AZURE_SEARCH_SERVICE, 
                                 credential=credential, 
                                 index_name=AZURE_SEARCH_INDEX)
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")
    
    results = search_client.search(  
        search_text=query,  
        vector_queries= [vector_query],
        select=["chunk"],
        top=1
    )

    if results is None:
        print("No results found.")
        return
    
    for result in results:  
        print(f"Score: {result['@search.score']}")
        print(f"Chunk: {result['chunk']}")

def rag_prompt_llm():
    # RAG Prompt Query using text-to-vector conversion of the query string

    token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")
    openai_client = AzureOpenAI(
        azure_endpoint=AZURE_OPENAI_ACCOUNT,
        azure_ad_token_provider=token_provider
    )

    deployment_name = os.getenv("AZURE_OPENAI_LLM_DEPLOYMENT")

    search_client = SearchClient(
        endpoint=AZURE_SEARCH_SERVICE,
        index_name=index_name,
        credential=credential
    )

    # Provide instructions to the model
    GROUNDED_PROMPT="""
    You are an AI assistant that helps users learn from the information found in the source material.
    Answer the query using only the sources provided below.
    Use bullets if the answer has multiple points.
    If the answer is longer than 3 sentences, provide a summary.
    Answer ONLY with the facts listed in the list of sources below. Cite your source when you answer the question
    If there isn't enough information below, say you don't know.
    Do not generate answers that don't use the sources below.
    Query: {query}
    Sources:\n{sources}
    """

    # Provide the search query. 
    # It's hybrid: a keyword search on "query", with text-to-vector conversion for "vector_query".
    # The vector query finds 50 nearest neighbor matches in the search index
    query="What's the NASA earth book about?"
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")

    # Set up the search results and the chat thread.
    # Retrieve the selected fields from the search index related to the question.
    # Search results are limited to the top 5 matches. Limiting top can help you stay under LLM quotas.
    search_results = search_client.search(
        search_text=query,
        vector_queries= [vector_query],
        select=["title", "chunk", "locations"],
        top=5,
    )

    # Newlines could be in the OCR'd content or in PDFs, as is the case for the sample PDFs used for this example.
    # Use a unique separator to make the sources distinct. 
    # We chose repeated equal signs (=) followed by a newline because it's unlikely the source documents contain this sequence.
    sources_formatted = "=================\n".join([f'TITLE: {document["title"]}, CONTENT: {document["chunk"]}, LOCATIONS: {document["locations"]}' for document in search_results])

    response = openai_client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": GROUNDED_PROMPT.format(query=query, sources=sources_formatted)
            }
        ],
        model=deployment_name
    )

    print(response.choices[0].message.content)

def vector_search_filter():
    # Query using text-to-vector conversion of the query string
    search_client = SearchClient(
        endpoint=AZURE_SEARCH_SERVICE,
        index_name=index_name,
        credential=credential
    )

    # Provide the search query. 
    # It's hybrid: a keyword search on "query", with text-to-vector conversion for "vector_query".
    # The vector query finds 50 nearest neighbor matches in the search index
    query="What's the NASA earth book about?"
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")

    # Set up the search results and the chat thread.
    # Retrieve the selected fields from the search index related to the question.
    # Search results are limited to the top 5 matches. Limiting top can help you stay under LLM quotas.
    # Add a filter that selects documents based on whether locations includes the term "ice".
    search_results = search_client.search(
        search_text=query,
        vector_queries= [vector_query],
        filter="search.ismatch('ice*', 'locations', 'full', 'any')",
        select=["title", "chunk", "locations"],
        top=5,
    )

    # Newlines could be in the OCR'd content or in PDFs, as is the case for the sample PDFs used for this example.
    # Use a unique separator to make the sources distinct. 
    # We chose repeated equal signs (=) followed by a newline because it's unlikely the source documents contain this sequence.
    sources_formatted = "=================\n".join([f'TITLE: {document["title"]}, CONTENT: {document["chunk"]}, LOCATIONS: {document["locations"]}' for document in search_results])
    
    print(sources_formatted)


def main():
    vector_search()
    rag_prompt_llm()
    vector_search_filter()

if __name__ == "__main__":
    main()