# Use the official Docker Hub Ubuntu base image
FROM ubuntu:24.04

# Prevent needing to configure debian packages, stopping the setup of
# the docker container.
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Add the Ubuntu .NET backports package repository
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    rm -rf /var/lib/apt/lists/*
RUN add-apt-repository ppa:dotnet/backports

# Install poetry and any other dependency that your worker needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    dotnet-runtime-9.0 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------
# Install ZimmermanTools
# ----------------------------------------------------------------------
# Download the tools using curl
RUN curl -L -o EvtxECmd.zip https://download.ericzimmermanstools.com/net9/EvtxECmd.zip
RUN curl -L -o MFTECmd.zip https://download.ericzimmermanstools.com/net9/MFTECmd.zip

# Unzip and clean up
RUN unzip EvtxECmd.zip -d /opt/zimmermantools && rm EvtxECmd.zip
RUN mkdir /opt/zimmermantools/MFTECmd
RUN unzip MFTECmd.zip -d /opt/zimmermantools/MFTECmd && rm MFTECmd.zip

# Sync EvtxECmd map files
RUN dotnet /opt/zimmermantools/EvtxeCmd/EvtxECmd.dll --sync
# ----------------------------------------------------------------------

# Configure debugging
ARG OPENRELIK_PYDEBUG
ENV OPENRELIK_PYDEBUG=${OPENRELIK_PYDEBUG:-0}
ARG OPENRELIK_PYDEBUG_PORT
ENV OPENRELIK_PYDEBUG_PORT=${OPENRELIK_PYDEBUG_PORT:-5678}

# Set working directory
WORKDIR /openrelik

# Install the latest uv binaries
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy poetry toml and install dependencies
COPY uv.lock pyproject.toml .

# Install the project's dependencies using the lockfile and settings
RUN uv sync --locked --no-install-project --no-dev

# Copy project files
COPY . ./

# Installing separately from its dependencies allows optimal layer caching
RUN uv sync --locked --no-dev

# Install the worker and set environment to use the correct python interpreter.
ENV PATH="/openrelik/.venv/bin:$PATH"

# Default command if not run from docker-compose (and command being overidden)
CMD ["celery", "--app=src.tasks", "worker", "--task-events", "--concurrency=1", "--loglevel=DEBUG"]
