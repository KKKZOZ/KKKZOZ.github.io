#! /usr/bin/env python3

import argparse
import sys
from pathlib import Path


def create_link_from_filename(md_file_path: Path) -> str:
    """
    Generates a markdown list item link based on a file path.

    Example:
        Input: Path('A Survey On Efficient Inference For Large Language Models.md')
        Output: '- [A Survey On Efficient Inference For Large Language Models](./a-survey-on-efficient-inference-for-large-language-models/)'
    """
    # Get the filename without the .md extension for the link text.
    # e.g., "A Survey On Efficient Inference For Large Language Models"
    link_text = md_file_path.stem

    # Create the URL part by making the stem lowercase and replacing spaces with hyphens.
    # e.g., "a-survey-on-efficient-inference-for-large-language-models"
    url_part = link_text.lower().replace(" ", "-")

    # Assemble the final markdown link string.
    return f"- [{link_text}](./{url_part}/)"


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

    # Convert the input string to a Path object for robust handling.
    directory = Path(args.directory_path)

    if not directory.is_dir():
        print(f"Error: Provided path '{directory}' is not a valid directory.")
        sys.exit(1)

    index_file = directory / "paper-index.md"

    # Check if paper-index.md exists. If not, exit with an error.
    if not index_file.is_file():
        print(f"Error: '{index_file}' not found in the specified directory.")
        sys.exit(1)

    # Read the current content of the index file to check for existing links.
    try:
        index_content = index_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error: Could not read '{index_file}': {e}")
        sys.exit(1)

    # Find all .md files in the directory.
    all_md_files = list(directory.glob("*.md"))

    links_to_add = []

    # Iterate over each markdown file found.
    for md_file in all_md_files:
        # Skip the index file itself.
        if md_file.samefile(index_file):
            continue

        # Generate the expected markdown link for the current file.
        expected_link = create_link_from_filename(md_file)

        # If the link is not already in the index content, add it to our list.
        if expected_link not in index_content:
            links_to_add.append(expected_link)

    # If there are new links to add, append them to the index file.
    if links_to_add:
        print(f"Found {len(links_to_add)} new link(s) to add.")
        try:
            with open(index_file, "a", encoding="utf-8") as f:
                # Add a newline first to ensure content starts on a new line.
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
