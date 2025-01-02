#!/usr/bin/env nix-shell
#! nix-shell -p python310 python312Packages.requests python312Packages.tqdm python312Packages.msgspec -i python
import json
import tqdm
import requests
import msgspec
from typing import Dict, List, Literal


type SystemStr = Literal["aarch64-darwin"] | Literal["x86_64-darwin"] | Literal["x86_64-linux"] | Literal["aarch64-linux"] | Literal["i686-linux"]

class Asset(msgspec.Struct):
    name: str
    browser_download_url: str

class Release(msgspec.Struct):
    tag_name: str
    assets: List[Asset]

class ProcessedDataVersion(msgspec.Struct):
    url: str
    version: str
    filename: str
    sha512: str = "" 

class ProcessedData(msgspec.Struct):
    hashes: Dict[str, Dict[str, str]] = dict() # Hashes are indexed by version -> filename
    # The processed data for each version and system
    version_data: Dict[str, Dict[SystemStr, ProcessedDataVersion]] = dict()


def parse_hashes(data):
    """
    Parse the provided hash-checksum data and return a dictionary of hashes with corresponding filenames.
    Args:
        data (str): The input data as a string where each line contains a hash and a filename.
    
    Returns:
        dict: A dictionary where the keys are the hashes and the values are the filenames.
    """
    parsed_data = {}
    
    # Split the data into lines
    lines = data.strip().split("\n")
    
    # Process each line
    for line in lines:
        # Split the line by space to separate hash and filename
        parts = line.split("  ")
        if len(parts) == 2:
            hash_value, filename = parts
            parsed_data[filename] = hash_value
        else:
            print(f"Skipping invalid line: '{line}'")
    
    return parsed_data


processed_data = ProcessedData()

# Fetch the JSON from GitHub API
url = 'https://api.github.com/repos/godotengine/godot-builds/releases?per_page=100'
response = requests.get(url)

try:
    releases = msgspec.convert(response.json(), type=List[Release])
except msgspec.ValidationError:
    print(f"ERROR: failed to parse github response '{response.json()}'")
    raise

# Process the JSON data
for release in tqdm.tqdm(releases):
    version = release.tag_name
    processed_data.version_data[version] = {}

    for asset in release.assets:
        
        if asset.name == "SHA512-SUMS.txt":
            response = requests.get(asset.browser_download_url)
            processed_data.hashes[version] = parse_hashes(response.content.decode('utf-8'))
        
        # Don't actually support mono versions
        if "mono" in asset.name:
            continue
        
        # Determine OS and Arch from the asset name
        systems: List[SystemStr] = []

        # For Godot 3.*
        if "x11.64" in asset.name:
            systems.append("x86_64-linux")
        elif "x11.32" in asset.name:
            systems.append("i686-linux")
        elif "osx.universal" in asset.name:
            systems.append("aarch64-darwin")
            systems.append("x86_64-darwin")
            
        # For Godot 4.*
        elif "linux.x86_64" in asset.name:
            systems.append("x86_64-linux")
        elif "linux.x86_32" in asset.name:
            systems.append("i686-linux")
        elif "linux.arm64" in asset.name:
            systems.append("aarch64-linux")
        elif "macos.universal" in asset.name:
            systems.append("aarch64-darwin")
            systems.append("x86_64-darwin")
        
        for system in systems:
            # Add data to the dictionary
            processed_data.version_data[version][system] = ProcessedDataVersion(
                url=asset.browser_download_url,
                version=version,
                filename=asset.name
            )
            
for version, data in processed_data.version_data.items():
    for system, processed_data_version in data.items():
        processed_data.version_data[version][system].sha512 = processed_data.hashes.get(version, {}).get(processed_data_version.filename, "")


# Save the data to a new file
with open("sources.json", "w") as f:
    json.dump(msgspec.to_builtins(processed_data.version_data), f, indent=2)

print("Data has been processed and saved to 'sources.json'.")
