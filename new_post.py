import os
from datetime import datetime

# --- Prompts ---
# Prompt for the blog post title.
title = input("Enter the blog post title: ")

# Prompt for tags (can be empty).
tags_input = input("Enter tags (comma-separated, or leave empty): ")

# --- Directory and File Name ---
# Define the directory where the post will be saved.
posts_dir = "content/posts/"

# Create the directory if it doesn't exist.
os.makedirs(posts_dir, exist_ok=True)

# Generate the filename from the title.
# Convert to lowercase and replace spaces with hyphens.
filename = title.lower().replace(" ", "-") + ".md"
filepath = os.path.join(posts_dir, filename)

# --- Date and Tags ---
# Get the current date.
current_date = datetime.now().strftime("%Y-%m-%d")

# Format the tags for the front matter.
if tags_input:
    # Split the input string into a list of tags.
    tags_list = [tag.strip() for tag in tags_input.split(",")]
    # Format the tags as a YAML list.
    tags_yaml = "\n".join([f"  - {tag}" for tag in tags_list])
else:
    tags_yaml = ""

# --- Content Template ---
# Create the markdown content with the YAML front matter.
content = f"""---
title: "{title}"
tags:
{tags_yaml}
date: {current_date}
showtoc: true
---
"""

# --- File Creation ---
# Write the content to the new markdown file.
with open(filepath, "w") as f:
    f.write(content)

# --- Confirmation ---
# Print a confirmation message to the user.
print(f"\nNew blog post created at: {filepath}")
