# Optional embedding-model dependency

The development context-search setup references Oracle's augmented ONNX distribution of the Sentence Transformers `all-MiniLM-L12-v2` model. The local database name `KCV_CONTEXT_MINILM` is this project's chosen installation name, not a claim of authorship of the model.

- Base model and model card: [sentence-transformers/all-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2). The card identifies the base model as Apache-2.0 and describes its 384-dimensional sentence/paragraph embeddings.
- Oracle-prepared distribution: [Pre-built embedding generation model](https://blogs.oracle.com/machinelearning/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai). Oracle describes augmentation with the preprocessing and postprocessing required for database use.
- Loading API: [DBMS_VECTOR.LOAD_ONNX_MODEL](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/load_onnx_model-procedure.html).

No model weights, ONNX binary, tokenizer, downloaded archive or upstream model source code is included in this repository or its public dataset. The installer obtains the model separately from an operator-supplied location. Direct download links that grant access are not stored in the repository.

The project's MIT licence covers its original integration code and documentation; it does not relicense this model, Oracle software or the downloaded distribution. Review and retain the applicable notices supplied with the chosen download, including its accompanying README. The base model card's licence label is not an assertion that it is the complete licence statement for every component of an augmented distribution. Redistributing model files would require a separate review of that exact distribution; this project does not currently do so.
