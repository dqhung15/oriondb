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

- Images: normalized -> feature extraction via CNN (edges -> textures -> shapes) -> vectorized.
- Similar vector representations -> visually similar images. Basis for **reverse image search**.
- Video: each frame -> feature vector -> sequence of feature vectors (a tensor) -> flattened for storage.

### Voice recognition

- Audio: digitized -> split into short frames -> each frame normalized, filtered, transformed -> feature vector.
- Whole audio = a sequence of feature vectors.
- Tolerance varies: speaker authentication (high precision) vs. conversational agents (more lenient).

### Recommender systems

- User behavior and item attributes are vectorized.
- Finding similar users or items -> nearest-neighbor search in vector space.
- Used by YouTube, Airbnb, e-commerce platforms.

### Chatbots & long-term memory (RAG)

Generative models have no built-in memory of past interactions; they respond only from immediate context. As a conversation grows longer, the model loses reference to earlier parts.

The generative model typically has some internal knowledge derived from the training data, but this lacks user preferences and past contexts.

This is solved by adding an external VDBMS:

- Past conversations and external documents are stored as vectors.
- User prompt -> vectorized -> query this VDBMS for top-k similar past conversations.
- Those are injected as additional context into the generative model.

This pattern is called **Retrieval-Augmented Generation (RAG)**.

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

Its architecture is similar to other DBMSs:

- **Query component**: parses queries, checks access rights, optimizes, routes to storage.
- **Storage component**: transaction logs (WAL), buffers, memory, CPU/GPU, specialized hardware (FPGAs, TPUs).
- **Optimizer/planner component**: decide which search path to take/which index to use.

Typically, data are vectorized outside VDBMS before being inserted. Queries must also be vectorized before the VDBMS can assess similarity.

## The Query Pattern & How VDBMS Serves It

Unlike SQL ("find the orders of a specific user"), vector queries ask: "find the k vectors most similar to this query vector".

From a developer perspective, VDBMS queries feel closer to **key-value store queries** than SQL: retrieve documents not by identifier but by one or several query vectors. The key difference from NoSQL: execution searches for **nearest neighbors**, not exact matches.

### Hybrid queries

In practice, queries often also need metadata filters: "find the most similar plays, but only from Greece, type=tragedy".

- Metadata -> indexed with traditional techniques (B+-trees).
- Vectors -> their own index structures.
- VDBMSs without native hybrid query support push this to the application layer.

### Similarity metrics

The similarity metric choice depends on data and context:

- **Euclidean distance (L2)**: straight-line distance, common in low-dimensional spaces.
- **Cosine similarity**: angle between vectors, regardless of magnitude; common in NLP.
- **Dot product**: sum of element-wise products.
- **Jaccard similarity**: shared over total elements, set-based.

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

- Speed vs accuracy Tradeoff
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
