#! /usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path


def create_link_from_front_matter(md_file_path: Path) -> str | None:
    """
    Generates a markdown list item link based on the 'title' attribute
    in a file's YAML front matter by manually parsing it.

    Returns the link string or None if the front matter/title is missing.
    """
    try:
        content = md_file_path.read_text(encoding="utf-8")

        # Regex to find the YAML front matter block (---...---) at the start of the file.
        match = re.match(r"^---\s*\n(.*?)\n---\s*", content, re.DOTALL)

        if not match:
            print(
                f"Warning: No YAML front matter found in '{md_file_path.name}'. Skipping."
            )
            return None

        # Extract the YAML content (the first matched group).
        yaml_content = match.group(1)

        link_text = None
        # Manually parse the YAML content line by line to find the title.
        for line in yaml_content.splitlines():
            # Check if the line starts with 'title:' after removing leading whitespace.
            if line.strip().startswith("title:"):
                # Split the line at the first colon to separate the key and value.
                parts = line.split(":", 1)
                # The value is the second part; strip whitespace from it.
                value = parts[1].strip()

                # Handle cases where the title is wrapped in single or double quotes.
                if (value.startswith('"') and value.endswith('"')) or (
                    value.startswith("'") and value.endswith("'")
                ):
                    # Remove the quotes from the start and end.
                    value = value[1:-1]

                link_text = value
                break  # Exit the loop once the title is found.

        if not link_text:
            print(
                f"Warning: 'title' attribute not found in YAML front matter of '{md_file_path.name}'. Skipping."
            )
            return None

        # Create the URL part by making the title lowercase and replacing spaces with hyphens.
        # This part remains the same.
        url_part = link_text.lower().replace(" ", "-")

        # Assemble the final markdown link string.
        return f"- [{link_text}](./{url_part}/)"

    except Exception as e:
        print(f"Warning: Could not read or process '{md_file_path.name}': {e}")
        return None


def main():
    """
    Main function to update the paper-index.md file.
    """
    parser = argparse.ArgumentParser(
        description="Update a paper-index.md file with missing links from the same directory."
    )
    parser.add_argument(
        "directory_path",
        type=str,
        help="The path to the folder containing the markdown files and paper-index.md.",
    )
    args = parser.parse_args()

    directory = Path(args.directory_path)

    if not directory.is_dir():
        print(f"Error: Provided path '{directory}' is not a valid directory.")
        sys.exit(1)

    index_file = directory / "paper-index.md"

    if not index_file.is_file():
        print(f"Error: '{index_file}' not found in the specified directory.")
        sys.exit(1)

    try:
        index_content = index_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error: Could not read '{index_file}': {e}")
        sys.exit(1)

    all_md_files = list(directory.glob("*.md"))
    links_to_add = []

    for md_file in all_md_files:
        if md_file.samefile(index_file):
            continue

        # Generate link from front matter; this can return None if it fails.
        expected_link = create_link_from_front_matter(md_file)

        # Only proceed if a link was successfully created and it's not already in the index.
        if expected_link and expected_link not in index_content:
            links_to_add.append(expected_link)

    if links_to_add:
        print(f"Found {len(links_to_add)} new link(s) to add.")
        try:
            with open(index_file, "a", encoding="utf-8") as f:
                f.write("\n")
                f.write("\n".join(links_to_add))
            print(f"Successfully updated '{index_file}'.")
        except Exception as e:
            print(f"Error: Could not write to '{index_file}': {e}")
            sys.exit(1)
    else:
        print("The paper-index.md file is already up-to-date.")


if __name__ == "__main__":
    main()
