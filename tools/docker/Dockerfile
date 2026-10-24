# Test box for DynastyALWL: Godot 4.7.2 + Voxel Tools 1.7 (headless, Linux) and the repo's test jobs.
# Separate from any game container. Build (from the repo root):  docker build -f tools/docker/Dockerfile -t dynasty-testbox .
# Needs engine/godot-4.7.2-voxel1.7-linux-headless.xz in the build context (the project's backup copy; not stored in git).
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends git python3 xz-utils ca-certificates tini && rm -rf /var/lib/apt/lists/*
COPY engine/godot-4.7.2-voxel1.7-linux-headless.xz /tmp/godot.xz
RUN mkdir -p /opt/godot && xz -dc /tmp/godot.xz > /opt/godot/godot && chmod +x /opt/godot/godot && rm /tmp/godot.xz && /opt/godot/godot --version
COPY tools/docker/run_jobs.sh /usr/local/bin/run_jobs.sh
RUN chmod +x /usr/local/bin/run_jobs.sh && useradd -m -u 1500 tester && mkdir -p /work /out && chown tester /work /out
USER tester
ENV GODOT_EXE=/opt/godot/godot PYTHONDONTWRITEBYTECODE=1
WORKDIR /work
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run_jobs.sh"]
CMD ["selftest"]
