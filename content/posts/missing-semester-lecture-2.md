---
title: "Missing Semester - Lecture 2"
tags:
- Course
- The Missing Semester
date: 2024-10-11
toc: true
weight: 10
---


## Shell Scripting

To assign variables in bash, use the syntax `foo=bar` and access the value of the variable with `$foo`.

> Note that `foo = bar` will not work since it is interpreted as calling the foo program with arguments `=` and `bar`.

bash uses a variety of special variables to refer to arguments, error codes, and other relevant variables:

- $0 - Name of the script
- $1 to $9 - Arguments to the script. $1 is the first argument and so on.
- $@ - All the arguments
- $# - Number of arguments
- $? - Return code of the previous command
- $$ - Process identification number (PID) for the current script
- !! - Entire last command, including arguments. A common pattern is to execute a command only for it to fail due to missing permissions; you can quickly re-execute the command with sudo by doing sudo !!
- $_ - Last argument from the last command. If you are in an interactive shell, you can also quickly get this value by typing Esc followed by . or Alt+.

Exit codes can be used to conditionally execute commands using && (and operator) and || (or operator).

Commands can also be separated within the same line using a semicolon `;`.

```bash
false || echo "Oops, fail"
# Oops, fail

true || echo "Will not be printed"
```

- **command substitution**: Whenever you place $( CMD ) it will execute CMD, get the output of the command and substitute it in place.
  - > `for file in $(ls)`
- **process substitution**: <( CMD ) will execute CMD and place the output in a temporary file and substitute the <() with that file’s name. This is useful when commands expect values to be passed by file instead of by STDIN.
  - > `diff <(ls foo) <(ls bar)`

### Shell Globbing

A glob (short for global) is a simplified pattern-matching mechanism typically used for matching file names or paths in Unix-like systems. Globs are commonly used with command-line tools like bash, find, and fd.

**Common Glob Patterns:**

- `*`: Matches zero or more characters.
  - Example: `*.txt` matches all files with a .txt extension.
- `?`: Matches exactly one character.
  - Example: file?.txt matches file1.txt, fileA.txt, but not file10.txt.
- `[abc]`: Matches one character that is either a, b, or c.
  - Example: file[1-3].txt matches file1.txt, file2.txt, and file3.txt.
- `[!abc]`: Matches one character that is not a, b, or c.
  - Example: file[!1-3].txt matches file4.txt, fileA.txt, etc.

Curly braces `{}` - Whenever you have a common substring in a series of commands, you can use curly braces for bash to expand this automatically.

```bash
convert image.{png,jpg}
# Will expand to
convert image.png image.jpg

cp /path/to/project/{foo,bar,baz}.sh /newpath
# Will expand to
cp /path/to/project/foo.sh /path/to/project/bar.sh /path/to/project/baz.sh /newpath

mv *{.py,.sh} folder
# Will move all *.py and *.sh files
```

### Shebang Line

A shebang looks like this:

```bash
#!/path/to/interpreter
```

The problem with hardcoding the interpreter is that **the interpreter may not always be installed at the exact same location on different systems**.

To make your script portable (able to run on different systems), it's better to use a more flexible method to locate the interpreter.

That's where `/usr/bin/env` comes in. The env command can locate the interpreter (like Python) by searching through the directories listed in the system's `PATH` environment variable.

So, you can write your shebang line like this:

```bash
#!/usr/bin/env python
```

## Shell Tools

### Find how to use commans

```bash
man <command>
tldr <command>
```

### Finding Files

Using `find` or `fd`.

```bash
# Find all directories named src
find . -name src -type d
# Find all python files that have a folder named test in their path
find . -path '*/test/*.py' -type f

# Delete all files with .tmp extension
find . -name '*.tmp' -exec rm {} \;
find root_path -name '*.ext' -exec wc -l {} \+;

```

- `{}` is a placeholder that find replaces with the current file's path that matches the search criteria.
- `\;` in the find command's -exec option serves as an escaped semicolon that terminates the command to be executed.
- `\+` to execute the command once with multiple files.

`fd` is better:

```bash
fd '*.py' .

fd '*.ext' root_path -x wc -l
fd '*.ext' root_path -X wc -l
```

### Finding Code

Using `rg`:

```bash
# Find all python files where I used the requests library
rg -t py 'import requests'
# Find all matches of foo and print the following 5 lines
rg foo -A 5

rg -t md 'shell' -A 3
```

### Find Shell Commands

The history command will let you access your shell history programmatically.

In most shells, you can make use of `Ctrl+R` to perform backwards search through your history.

## Exercises

### 2

```bash
#!/bin/bash

# Function to save the current working directory
marco() {
  export pos=$(pwd)  # Save the current directory and export it
}

# Function to cd back to the saved directory
polo() {
  if [ -z "$pos" ]; then
    echo "Error: No directory saved. Please run marco first."
  else
    cd "$pos" || echo "Error: Could not change to directory $pos"
  fi
}

```

```fish
# Save the current working directory
function marco
    set -g pos (pwd)  # Save the current directory to a global variable
end

# Change back to the saved directory
function polo
    if test -n "$pos"
        cd $pos
    else
        echo "Error: No directory saved. Please run marco first."
    end
end

```

### 3

```bash
#!/usr/bin/env bash

n=0

output_file="output.log"
error_file="error.log"

while true;do
  ((n++))
  ./fail-rarely.sh > "$output_file" 2> "$error_file"

  if [[ $? -ne 0 ]];then
    echo "Command failed after $n runs."
    break
  fi
done

# Print the captured output and error
echo "Standard Output:"
cat "$output_file"

echo "Standard Error:"
cat "$error_file"
```

### 4

**About `xargs`**:

It takes the output of one command and uses it as the arguments for another command.

```bash
command | xargs [options] [command]
```

Examples:

Delete Files:

```bash
fd '\.log$' | xargs rm
```

Search Files:

```bash
fd '\.py$' | xargs rg "sys"
```

Run Multiple Commands in Parallel:

```bash
fd '\.jpg$' | xargs -P 4 -n 10 cp -t /backup/images/
```

- `-P 4`: Runs 4 commands in parallel.
- `-n 10`: Copies 10 files at a time.

Download Files:

```bash
cat urls.txt | xargs -n 1 curl -O
```

- `-O`: Downloads the file and saves it with the same name

```bash
fd '\.py$' . | xargs zip my_py.zip
```

### 5

```bash
fd -t f . -x stat --format='%y %n' {} | sort
```
