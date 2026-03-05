import os
import shutil
import subprocess
import time
from pathlib import Path
from uuid import uuid4

from openrelik_worker_common.file_utils import create_output_file
from openrelik_worker_common.task_utils import create_task_result, get_input_files

from .app import celery

TASK_NAME = "openrelik-worker-zimmermantools.tasks.mftecmd"

TASK_METADATA = {
    "display_name": "MFTECmd JSON output",
    "description": "Parse MFT and create JSON output",
}

COMPATIBLE_INPUTS = {
    "data_types": [],
    "mime_types": [],
    "filenames": ["*"],
}

@celery.task(bind=True, name=TASK_NAME, metadata=TASK_METADATA)
def evtxecmd(
    self,
    pipe_result: str = None,
    input_files: list = None,
    output_path: str = None,
    workflow_id: str = None,
    task_config: dict = [],
) -> str:
    output_files = []
    input_files = get_input_files(pipe_result, input_files or [], filter=COMPATIBLE_INPUTS)
    if not input_files:
        return create_task_result(
            output_files=output_files,
            workflow_id=workflow_id,
            command="",
        )

    # Create a directory for storing the MFTEECmd output file
    output_dir = os.path.join(output_path, uuid4().hex)
    os.mkdir(output_dir)

    for file in input_files:
        mft_file = file.get("path")

        # Execute MFTECmd on the provided input file
        command = [
            "dotnet",
            "/opt/zimmermantools/MFTECmd/MFTECmd.dll",
            "--json",
            output_dir,
            "-f",
            mft_file,
        ]

        INTERVAL_SECONDS = 2
        process = subprocess.Popen(command)
        while process.poll() is None:
            self.send_event("task-progress", data=None)
            time.sleep(INTERVAL_SECONDS)

    # Return output file
    output_dir_path = Path(output_dir)
    json_files = [
        file for file in output_dir_path.glob("*") if file.is_file()
    ]
    for file in json_files:
        original_path = str(file.relative_to(output_dir_path))
        output_file = create_output_file(
            output_path,
            display_name=file.name,
            original_path=original_path,
            data_type="openrelik:mftecmd:json_output",
        )
        os.rename(file.absolute(), output_file.path)
        output_files.append(output_file.to_dict())

    # Remove output directory
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)

    return create_task_result(
        output_files=output_files,
        workflow_id=workflow_id,
        command=" ".join(command),
    )

