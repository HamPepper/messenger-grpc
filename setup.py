import subprocess

from contextlib import suppress
from pathlib import Path
from setuptools import Command, setup
from setuptools.command.build import build


class CustomCommand(Command):
    def initialize_options(self) -> None:
        self.bdist_dir = None
        self.proto_msgs_path = None
        self.pkg_name = None

    def finalize_options(self) -> None:
        self.pkg_name = self.distribution.get_name().replace("-", "_")
        self.proto_msgs_path = Path(self.pkg_name).parent / "proto"
        with suppress(Exception):
            self.bdist_dir = Path(self.get_finalized_command("bdist_wheel").bdist_dir)  # type: ignore

    def get_source_files(self) -> "list[str]":
        if self.proto_msgs_path.is_dir():  # type: ignore
            return [str(path) for path in self.proto_msgs_path.rglob("*.proto")]  # type: ignore
        else:
            return []

    def run(self) -> None:
        if self.bdist_dir:
            print(f"gRPC proto files are located in: {self.proto_msgs_path}")

            # create package structure
            output_dir = self.bdist_dir  # type: ignore
            output_dir.mkdir(parents=True, exist_ok=True)

            # generate python classes
            protoc_call = [
                "python3",
                "-m",
                "grpc_tools.protoc",
                f"--proto_path={self.proto_msgs_path}",
                f"--python_out={output_dir}",
                f"--grpc_python_out={output_dir}",
                *self.get_source_files(),
            ]
            subprocess.call(protoc_call)


class CustomBuild(build):
    sub_commands = [("build_custom", None)] + build.sub_commands


setup(cmdclass={"build": CustomBuild, "build_custom": CustomCommand})
