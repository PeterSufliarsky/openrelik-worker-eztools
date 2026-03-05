# OpenRelik worker for running Eric Zimmerman's tools on input files

## Description
This worker can be used to parse input files using forensic tools created by Eric Zimmerman. See https://ericzimmerman.github.io for more information.

Currently supported tools:
* EvtxECmd

## Deploy
Add the below configuration to the OpenRelik docker-compose.yml file.

```
openrelik-worker-eztools:
    container_name: openrelik-worker-eztools
    image: openrelik-worker-eztools:latest
    restart: always
    environment:
      - REDIS_URL=redis://openrelik-redis:6379
      - OPENRELIK_PYDEBUG=0
    volumes:
      - ./data:/usr/share/openrelik/data
    command: "celery --app=src.app worker --task-events --concurrency=4 --loglevel=INFO -Q openrelik-worker-eztools"
    # ports:
      # - 5678:5678 # For debugging purposes.
```

## Test
```
uv sync --group test
uv run pytest -s --cov=.
```
