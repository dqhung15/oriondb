---
_label: "Workflows for Vector DBMS"
---

This section researchs about the workflows or the tasks that necessitate vector DBMS.

This will answer:

1. Why do we need vector DBMS? Which tasks do other DBMS fall short in?
2. What is the query pattern underlying these tasks?
3. The general idea of why Vector DBMS efficiently serves this query pattern.

## Context & Motivation

In recent applications, there is a trend of working with rich unstructured data: texts, images, audio, video.

In these applications, there is often a need to search for relevant data based on some input data (called **queries**).

To do that, **vectorization** is often used:

- The rich data are encoded into n-dimensional numerical vectors, that embeds some underlying patterns of the data. They are also called **feature vectors** or **vector embeddings**.
- The more similar the data, the closer the vectors.

The problem:

- Relational and NoSQL databases are built for **exact-match queries**: "find orders of a specific user", "find products on sale". Data is human-readable: numbers, strings, timestamps. As a result, they have no native way to ask "find things *similar* to this".
- Vector data breaks these assumptions with two properties: **high dimensionality** and **sparsity**, both needing specialized storage, indexing, and query execution.

## Use Cases

All vector DB retrieval is based on **approximate similarity search**. Any data that can be meaningfully vectorized is a candidate.

### Image & video similarity search

The problem is finding images or videos that are visually similar to a given input, without relying on tags or metadata.

The solution:

- Images are normalized (size, pixel values), then passed through a CNN that extracts increasingly abstract features: from simple edges and shapes to textures like fur or foliage.
- These features are vectorized and stored in the VDBMS. Similar vector representations -> visually similar images. This is the basis for **reverse image search**.

For video, the same idea applies but with an added temporal dimension:

- Video is broken down into individual frames (or a representative subset).
- Each frame -> feature vector representing its content.
- Since temporal order matters (a Greek play can go from comedy to tragedy), frames are combined into a sequence -> a 3D tensor (frames x features x time) -> flattened and stored in the VDBMS.

### Voice recognition

The problem is identifying or understanding audio input, whether for authenticating a speaker or recognizing spoken words.

The solution:

- Audio is digitized and split into short frames, each representing a segment.
- Each frame is normalized, filtered, and transformed -> feature vector.
- The whole audio = a sequence of feature vectors, stored in the VDBMS.

The required similarity tolerance differs by use case:

- **Speaker authentication**: high tolerance, the voice must closely match the stored recording.
- **Conversational agents**: sequences of vectors are fed into a neural network to recognize and classify spoken words, then respond via a generative model. The similarity tolerance here is more lenient than speaker authentication.

### Recommender systems

The problem is finding items or users relevant to a specific user, based on behavior and preferences. Explicit signals like ratings or categories are too sparse and rigid to capture the full picture.

The solution:

- User behavior and item attributes are encoded as vectors and stored in the VDBMS.
- Finding similar users or relevant items -> nearest-neighbor search: "find the k users or items most similar to this query vector".

This is used by YouTube, Airbnb, and many e-commerce platforms.

### Chatbots & long-term memory (RAG)

Generative models have no built-in memory of past interactions; they respond only from immediate context. As a conversation grows longer, the model loses reference to earlier parts.

The generative model typically has some internal knowledge derived from the training data, but this lacks user preferences and past contexts.

This is solved by adding an external VDBMS:

- Past conversations and external documents are stored as vectors.
- User prompt -> vectorized -> query this VDBMS for top-k similar past conversations.
- Those are injected as additional context into the generative model.

This pattern is called **Retrieval-Augmented Generation (RAG)**.

```mermaid
flowchart LR
  subgraph app [Application]
    A[User prompt]
  end

  subgraph mem [VDBMS - Long-term memory]
    B[Vectorization]
    C[(Vector store)]
  end

  subgraph gen [Generative model]
    D[Response]
  end

  A -->|vectorize| B
  B -->|query top-k| C
  C -->|similar past context| gen
  A --> gen
  gen --> D
  D -->|store| B
```

## Fundamentals of VDBMS

A VDBMS is a specialized DBMS focused on efficient management of **high-dimensional vector data**.

It is functional software (not just a library): querying, indexing, access control, backups, scalability, integrations.

Systems focusing only on 2D/3D geospatial data are not considered VDBMSs.

### Vector as Data Representations

The VDBMS for each object, stores:

- The vector (the embedding).
- A vector identifier (unique ID).
- Vector metadata (structured attributes: type, country, timestamp...).
- The **payload**: original pre-vectorized data (e.g., the raw text of a play).

### VDBMS Architecture

In terms of architecture, a VDBMS is not very different from other DBMSs:

- **Query component**: parses queries, checks access rights, optimizes, routes to storage.
- **Storage component**: transaction logs (WAL), buffers, memory, CPU/GPU, and possibly specialized hardware (FPGAs, TPUs).
- **Optimizer/planner component**: decides which search path to take and which index to use.

One thing worth noting is that data is typically vectorized outside the VDBMS before being inserted. The same applies to queries: a natural language query must also be vectorized before the VDBMS can assess similarity.

```mermaid
flowchart LR
  subgraph insert [Insert path]
    S[(Source data)] -->|vectorize| V1[Vectorization]
    V1 --> I[Indexing]
    I --> DB[(Vector store)]
  end

  subgraph query [Query path]
    App[Application] -->|vectorize| V2[Vectorization]
    V2 -->|query| DB
    DB -->|top-k results| App
  end
```

## The Query Pattern in VDBMS

In relational databases, queries take forms like "find the orders of a specific user" or "find products on sale". Vector queries are fundamentally different: they ask "find the k vectors most similar to this query vector". This is **k-Nearest Neighbor (kNN) search**, or in practice, **Approximate Nearest Neighbor (ANN) search**.

From a developer perspective, VDBMS queries feel closer to **key-value store queries** than SQL: documents are retrieved not by identifier but by one or several query vectors. The key difference from NoSQL though is that execution searches for **nearest neighbors**, not exact matches.

### Hybrid queries

In practice, pure vector similarity is often not enough. Queries frequently need to combine vector search with structured filters, for example: "find the most similar plays, but only from Greece, type=tragedy". These are called **hybrid queries**.

The two sides are indexed differently:

- Metadata -> indexed with traditional techniques like B+-trees, similar to RDBMS.
- Vectors -> their own index structures optimized for similarity search.

VDBMSs without native hybrid query support push the metadata filtering responsibility to the application layer.

### Similarity metrics

To compare vectors, a distance or similarity metric is needed. The choice depends on the data and context:

- **Euclidean distance (L2)**: straight-line distance between two points; common in low-dimensional spaces.
- **Cosine similarity**: measures the angle between two vectors, regardless of their magnitude; common in NLP where direction matters more than scale.
- **Dot product**: sum of element-wise products; related to cosine similarity but magnitude-sensitive.
- **Jaccard similarity**: ratio of shared elements to total elements; set-based, useful for sparse data.

### Indexing

After vectorization, vectors are indexed so at query time the system does not scan everything. Index creation is expensive but done once. Most indices are **lossy approximations**, so there is always a tradeoff between **accuracy and speed**. The optimizer selects the most suitable index given data and query characteristics, similar to a query optimizer in a relational DBMS.

| Index | Mechanism | Best for | Tradeoff |
|---|---|---|---|
| Product Quantization (PQ) | Divides vectors into sub-vectors, compresses | Image search | Lossy; reduces accuracy |
| Locality-Sensitive Hashing (LSH) | Hashes similar vectors to same buckets | Near-duplicate detection | Requires parameter tuning |
| Hierarchical Navigable Small World (HNSW) | Hierarchical graph with fast neighborhood exploration | Recommendation, text search | Complex structure, space overhead |
| R-trees | Hierarchical bounding boxes | Geospatial / spatial data | Slower NN search |
| KD-trees | Binary partitioning along dimensions | Low-dimensional ML/clustering | Inefficient at high dimensions |
| Random Projection | Projects high-dim data randomly | Text classification, clustering | May lose information |

Choice of index depends on:

- Data characteristics
- Dimensionality
- Search requirements

## Current Challenges

- **Speed vs accuracy tradeoff**: Since most VDBMS queries go through ANN, this tradeoff is more central here than in any other data model. Lossless indices (e.g. R-trees) preserve accuracy but are slower; lossy indices (e.g. PQ) trade some accuracy for speed and reduced storage. This tension is especially sharp in large datasets where both are business-critical, like financial decision support systems where results must be fast and correct.
- Growing dimensionality and sparsity
  As domain needs grow, vectors need more dimensions. Two problems follow.
  - **Distance unreliability:** In high-dimensional spaces, volume grows exponentially but the number of vectors does not. Points concentrate near the hypersurface, so distances between vectors become increasingly similar -> proximity loses meaning. Developing effective distance measures is an open research problem.
  - **Increased sparsity:** Dimensions specific to one domain (e.g., cat features) don't contribute signal for others. Indexing algorithms designed for dense data struggle with sparse high-dimensional vectors.
- Achieving general maturity
  - VDBMSs are relatively novel. Stability, reliability, and query optimization are still under drastic development, unlike mature relational DBMSs with decades of bug fixes, broad feature sets, and large communities.
  - Security is a particular gap: VDBMSs commonly store sensitive data (private conversations, biometric data, geospatial intelligence) but lack the battle-tested access control of older systems.

## References

- Vector database management systems - Taipalus (2024): [Paper](https://arxiv.org/abs/2309.11322)

  ![Annotated Taipalus paper](./2309.11322v2.pdf)
