# cdm_bakta_proteins

CTS (CDM Task Service) job wrapper for [Bakta's protein-input mode](https://github.com/oschwengers/bakta), which annotates pre-existing protein sequences without re-predicting genes. Sibling to [cdm_bakta](https://github.com/kbaseincubator/cdm_bakta).

## When to use this vs cdm_bakta

| Tool | Input | What it does | Output locus tags |
|------|-------|--------------|-------------------|
| `cdm_bakta` | nucleotide assembly (`.fna`) | predicts genes + annotates | bakta-generated (e.g., `AHLLAC_0001`) |
| `cdm_bakta_proteins` (this) | protein FASTA (`.faa`) | annotates only, no gene-calling | preserved from input |

Use this when the input proteins already have meaningful locus tags (NCBI RefSeq, prior annotation, pre-existing pipeline output, etc.) and you want bakta's annotation without losing those identifiers.

## Container

Wraps the official [`oschwengers/bakta`](https://hub.docker.com/r/oschwengers/bakta) image (v1.12.0), invoking the `bakta_proteins` binary instead of `bakta`. Also overlays diamond v2.2.0 (same as `cdm_bakta:0.1.3`) to avoid the intermittent pseudogene-detection deadlock that affects the diamond v2.1.21 shipped in the conda bakta package. See [oschwengers/bakta#424](https://github.com/oschwengers/bakta/issues/424).

Published to `ghcr.io/kbaseincubator/cdm_bakta_proteins`.

**Entrypoint:** `bakta_proteins`. Append flags as arguments.

**Reference data:** Same Bakta DB as `cdm_bakta`. CTS mounts the bundle at `/ref_data/db/`. The container reads it via `BAKTA_DB=/ref_data/db` baked into the image, so callers do NOT need to pass `--db` on the command line.

## Usage via CTS

```python
job = tscli.submit_job(
    "ghcr.io/kbaseincubator/cdm_bakta_proteins:0.1.0@sha256:<digest>",
    input_files,                         # protein FASTA (.faa or .faa.gz)
    "cts/io/<user>/output/bakta_proteins/run1",
    cluster="kbase",
    declobber=True,
    output_mount_point="/out",
    args=[
        "--output", "/out",
        "--threads", "4",
        "--force",                # bakta refuses to overwrite the pre-created /out without this
        tscli.insert_files(),
    ],
    num_containers=len(input_files),
    cpus=4,
    memory="16GB",
    runtime="PT1H",
)
```

## Output

Per input protein FASTA, bakta_proteins produces:
- `<prefix>.tsv`: per-locus annotation table (Sequence Id, Type, Start, Stop, Strand, Locus Tag, Gene, Product, DbXrefs). **Imported to Delta Lake.**
- `<prefix>.gff3`, `.gbff`, `.embl`: standardized sequence formats
- `<prefix>.faa`, `.hypotheticals.faa`: annotated proteins
- `<prefix>.json`: full machine-readable annotation data
- `<prefix>.txt`: summary
- `<prefix>.log`: bakta run log
