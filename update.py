#!/usr/bin/env nix-shell
#! nix-shell -p python312 python312Packages.tqdm python312Packages.msgspec python312Packages.gitpython -i python
import json
import os
import git
import shutil

import tqdm
import msgspec
from typing import Dict, List, Literal


type SystemStr = (
    Literal["aarch64-darwin"]
    | Literal["x86_64-darwin"]
    | Literal["x86_64-linux"]
    | Literal["aarch64-linux"]
    | Literal["i686-linux"]
)


class FileInfo(msgspec.Struct):
    filename: str
    checksum: str

    @property
    def systems(self) -> List[SystemStr]:
        """
        Determines the supported systems (OS and architecture) based on the filename.

        Returns:
            List of systems (e.g., "x86_64-linux", "aarch64-darwin") the file is compatible with.
        """
        systems: List[SystemStr] = []

        # For Godot 3.*
        if "x11.64" in file.filename:
            systems.append("x86_64-linux")
        elif "x11.32" in file.filename:
            systems.append("i686-linux")
        elif "osx.universal" in file.filename:
            systems.append("aarch64-darwin")
            systems.append("x86_64-darwin")

        # For Godot 4.*
        elif "linux.x86_64" in file.filename:
            systems.append("x86_64-linux")
        elif "linux.x86_32" in file.filename:
            systems.append("i686-linux")
        elif "linux.arm64" in file.filename:
            systems.append("aarch64-linux")
        elif "macos.universal" in file.filename:
            systems.append("aarch64-darwin")
            systems.append("x86_64-darwin")

        return systems


class ReleaseInfo(msgspec.Struct):
    name: str  # Name of the release (e.g., "4.4-dev6")
    version: str  # Version of the release (e.g., "4.4")
    status: str  # Status of the release (e.g., "dev6")
    release_date: int  # Release date in Unix timestamp format
    git_reference: str  # Git reference for the release (e.g., commit hash)
    files: List[FileInfo]  # List of files included in this release


class BuildsData(msgspec.Struct):
    url: str
    version: str
    sha512: str


class GodotBuildsUpdater(msgspec.Struct):
    # The processed data for each version and system
    builds: Dict[str, Dict[SystemStr | Literal["export_templates"], BuildsData]] = (
        dict()
    )

    def save(self):
        """
        Saves the processed version data to a file as JSON.
        """
        with open("sources.json", "w") as f:
            json.dump(msgspec.to_builtins(self.builds), f, indent=2, sort_keys=True)

        print("Data has been processed and saved to 'sources.json'.")


updater = GodotBuildsUpdater()

godot_builds_repo_url = "https://github.com/godotengine/godot-builds.git"
godot_builds_dir = ".godot-builds"
godot_build_releases_path = f"{godot_builds_dir}/releases/"

# Clone the GitHub repository into a local directory
if os.path.isdir(godot_builds_dir):
    shutil.rmtree(godot_builds_dir)
git.Repo.clone_from(godot_builds_repo_url, godot_builds_dir)

# Loop through all files in the releases directory and process JSON files
for filename in tqdm.tqdm(os.listdir(godot_build_releases_path)):
    # Check if the file is a JSON file
    if not filename.endswith(".json"):
        continue

    file_path = os.path.join(godot_build_releases_path, filename)

    # Open and parse the JSON file
    with open(file_path, "r") as fd:
        json_data = json.load(fd)

    release_info = msgspec.convert(json_data, type=ReleaseInfo)

    if "-" not in release_info.name:
        release_info.name += "-stable"

    updater.builds[release_info.name] = {}

    # Loop through each file in the release
    for file in release_info.files:
        # Don't actually support "mono" versions
        if "mono" in file.filename:
            continue

        elif "export_templates" in file.filename:
            updater.builds[release_info.name]["export_templates"] = BuildsData(
                url=f"https://github.com/godotengine/godot-builds/releases/download/{release_info.name}/{file.filename}",
                version=release_info.name,
                sha512=file.checksum,
            )

        else:
            #  For each supported system, add relevant build data.
            for system in file.systems:
                updater.builds[release_info.name][system] = BuildsData(
                    url=f"https://github.com/godotengine/godot-builds/releases/download/{release_info.name}/{file.filename}",
                    version=release_info.name,
                    sha512=file.checksum,
                )

    # If no files have been saved, drop the version.
    if not updater.builds[release_info.name]:
        updater.builds.pop(release_info.name)

# Save the processed data to 'builds.json'.
updater.save()
