# cdm_bakta_proteins

CTS (CDM Task Service) job wrapper for [Bakta's protein-input mode](https://github.com/oschwengers/bakta), which annotates pre-existing protein sequences without re-predicting genes. Variant of [cdm_bakta](https://github.com/kbaseincubator/cdm_bakta) for the protein-input mode.

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
    "ghcr.io/kbaseincubator/cdm_bakta_proteins:0.1.0@sha256:ba41718caf200d897c01e53b2a0d58f953b30a8e15d1435b516f912f0142d89e",
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
    num_containers=len(input_files),     # one protein FASTA per invocation
    cpus=4,
    memory="16GB",
    runtime="PT1H",                      # per container; the CTS default is only 60 s
)
```

## Output

Per input protein FASTA `<prefix>`:
- `<prefix>.tsv`: per-protein annotation table, 10 columns: `ID`, `Length`, `Gene`, `Product`, `EC`, `GO`, `COG`, `RefSeq`, `UniParc`, `UniRef`. Comment lines start with `#` (bakta and DB versions). `ID` is the input identifier, unchanged.
- `<prefix>.inference.tsv`: which database lookup produced each annotation
- `<prefix>.hypotheticals.tsv`: details for hypothetical proteins. In bakta 1.12.x the rows have fewer fields than the header (an upstream formatting bug), so read these details from the `.json` instead.
- `<prefix>.json`: full machine-readable annotation data
- `<prefix>.faa`: annotated proteins
- `<prefix>.log`: bakta run log

Protein mode does not produce the genome-mode files (`.gff3`, `.gbff`, `.embl`, `.txt`, plots).

`COG` and `RefSeq` can be empty for every protein of a genome without anything being wrong. Both come only from RefSeq protein accessions that are current in the DB; genomes whose RefSeq entries were retired get none. In a test with E. coli K-12, both columns were filled for most proteins.

There is no lakehouse importer for bakta_proteins yet.
