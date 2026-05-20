FROM oschwengers/bakta:v1.12.0

# Reference data (Bakta DB v6) is mounted by CTS at /ref_data.
# After CTS unpacks the bundle, the database lives at /ref_data/db/.
# This is the SAME bundle used by cdm_bakta (bakta and bakta_proteins
# share the database).
ENV BAKTA_DB /ref_data/db

# bakta_proteins is installed via conda at /opt/conda/bin/bakta_proteins.
# Same PATH rationale as cdm_bakta: keep /opt/conda/bin on PATH so the
# tool itself and any subprocesses (hmmer, diamond, etc.) resolve.
ENV PATH="/opt/conda/bin:${PATH}"

# Overlay diamond v2.2.0 over the conda-shipped binary, same as cdm_bakta:0.1.3.
# Reason: the conda-shipped diamond (v2.1.21) intermittently hangs at the
# alignment step. Confirmed upstream as a diamond issue (oschwengers/bakta#424,
# bbuchfink/diamond#930). v2.2.0 release notes call out "Fixed an issue that
# could cause hanging instead of correct termination in case of an error".
ARG DIAMOND_VERSION=2.2.0
RUN cd /tmp \
 && wget -q https://github.com/bbuchfink/diamond/releases/download/v${DIAMOND_VERSION}/diamond-linux64.tar.gz \
 && tar xzf diamond-linux64.tar.gz \
 && install -m 0755 diamond /opt/conda/bin/diamond \
 && rm -f diamond-linux64.tar.gz diamond \
 && /opt/conda/bin/diamond version

ENTRYPOINT ["bakta_proteins"]
