## Pre-requisite
- Deploy the following models on Azure OpenAI:
    - `text-embedding-3-large` on Azure OpenAI for embeddings
    - `gpt-4o` on Azure OpenAI for chat completion
- For Azure AI Search, ensure caller identity has following roles:
    - Search Index Data Contributor
    - Search Service Contributor
- For Azure OpenAI, ensure caller identity has at least `Azure AI User` role.
- For Azure Storage, ensure caller identity has `Storage Blob Data Contributor` role.
- For data pipeline work, ensure Search MSI has following roles:
    - `Storage Blob Data Reader` role on Storage account (helps read blobs)
    - `Cognitive Services OpenAI User` role on Foundry account (helps call LLM model from Foundry) or OpenAI account
    - `Cognitive Services User` role on Foundry account (helps on billable resource part in cognitive skill)
- For semantic ranker to work, go to: Azure Portal > Search service > Settings > Premium features > Enable "Free" Plan (to test); Otherwise, go for standard plan for enterprise level features.

## RAG pattern
- Search index is a large collection of chunks
- Chunk is core element of search document in RAG pattern
- Chunked content typically derives from a larger documentm, where the schema is organized around chunks

## Good RAG solution
In a good RAG solution, following qualities are important.

- Returns chunks that are relevant to the query and readable to the LLM. LLMs can handle a certain level of dirty data in chunks, such as mark up, redundancy, and incomplete strings. While chunks need to be readable and relevant to the question, they don't need to be pristine.
- Maintains a parent-child relationship between chunks of a document and the properties of the parent document, such as the file name, file type, title, author, and so forth. To answer a query, chunks could be pulled from anywhere in the index. Association with the parent document providing the chunk is useful for context, citations, and follow up queries.
- Accommodates the queries you want create. You should have fields for vector and hybrid content, and those fields should be attributed to support specific query behaviors, such as searchable or filterable. You can only query one index at a time (no joins) so your fields collection should define all of your searchable content.
- Your schema should either be flat (no complex types or structures), or you should format the complex type output as JSON before sending it to the LLM.

## For Azure AI Search

```
pip install azure-search-documents==11.7.0b2
```

```
pip install python-dotenv
```

## Run the sample

```powershell
cd azure-search-rag (if not already)

# rename .env.example to .env/ feed required service/ model details

# get blob storage ready with grounded data
.\0.prep_data_storage.ps1

# build rag pipeline
python 1.build_rag_pipeline.py

# generate search results
python 2.search_generate.py

# maximize relevance of search results
python 3.maximize_relevance.py
```

## Reference
- [Package referecnce for azure-search-documents](https://pypi.org/project/azure-search-documents)
- [Python sdk sample references on azure-search-documents](https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/search/azure-search-documents/samples)
- [Classic RAG with Azure AI Search on NASA Earth Book dataset](https://github.com/Azure-Samples/azure-search-classic-rag/tree/main)