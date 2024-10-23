---
title: "Missing Semester - Lecture 4"
tags:
- Course
categories:
- [Course]
date: 2024-10-15
---


```bash
# journalctl run remotely, grep run locally
ssh myserver journalctl | grep sshd
# both commands run remotely
ssh myserver "journalctl | grep sshd"
```


## `sed`

`sed` (Stream Editor) is a powerful command-line tool in Unix/Linux that is used for parsing and transforming text, typically used for finding, replacing, or deleting content in a file or input stream.

Common sed Commands:

- **Substitution** (`s`):

```bash
sed 's/pattern/replacement/' file
```
- s: The substitution command.
- pattern: The string or pattern to search for.
- replacement: The string to replace the pattern with.

Example:

```bash
sed 's/apple/orange/' fruits.txt
```
This replaces the first occurrence of the word "apple" with "orange" on each line.

- **Delete** (`d`):

```bash
sed '/pattern/d' file
```
Deletes all lines that match a given pattern.

- **Print** (`p`):

```bash
sed -n 'p'
```
Prints lines (used with -n to suppress default behavior).

Example:

```bash
# This will print lines 2 and 3
sed -n '2,3p' example.txt
```

### **Basic, Common, and Most-Used Regular Expressions (Regex)**

#### **Basic Regex Symbols and Their Meaning**

Quantifiers specify how many instances of a character, group, or character class must be present in the input for a match.

1. **`.` (dot)**: Matches **any single character** except a newline.
     - Regex: `a.b`
     - Matches: `"a1b"`, `"axb"`, `"a b"`
     - Does **not** match: `"ab"`, `"a\nb"`

2. **`*` (asterisk)**: Matches **zero or more** occurrences of the preceding character.
   - Regex: `ca*t`
   - Matches: `"ct"`, `"cat"`, `"caat"`, `"caaaaat"`

3. **`+` (plus)**: Matches **one or more** occurrences of the preceding character.
   - Regex: `ca+t`
   - Matches: `"cat"`, `"caat"`
   - Does **not** match: `"ct"`

4. **`?` (question mark)**: Matches **zero or one** occurrence of the preceding character.
   - Regex: `ca?t`
   - Matches: `"cat"`, `"ct"`
   - Does **not** match: `"caat"`

5. **`{}` (braces)**: Matches a specific number of occurrences.
   - `{n}`: Exactly `n` occurrences.
     - Regex: `a{3}`
     - Matches: `"aaa"`
   - `{n,}`: At least `n` occurrences.
     - Regex: `a{2,}`
     - Matches: `"aa"`, `"aaa"`, `"aaaa"`
   - `{n,m}`: Between `n` and `m` occurrences.
     - Regex: `a{2,4}`
     - Matches: `"aa"`, `"aaa"`, `"aaaa"`
     - Does **not** match: `"a"`, `"aaaaa"`

#### **Anchors** (for Position Matching)

Anchors don’t match characters, but rather positions in the string.

1. **`^` (caret)**: Matches the **start** of a string.
   - Regex: `^hello`
   - Matches: `"hello world"`
   - Does **not** match: `"world hello"`

2. **`$` (dollar sign)**: Matches the **end** of a string.
   - Regex: `world$`
   - Matches: `"hello world"`
   - Does **not** match: `"world hello"`

3. **`\b` (word boundary)**: Matches the position between a word character (`\w`) and a non-word character.
   - Regex: `\bcat\b`
   - Matches: `"cat is here"`, `"I have a cat"`
   - Does **not** match: `"caterpillar"`, `"catch"`

<!-- #### **Character Classes**

Character classes allow you to match one character from a specific set.

1. **`[]` (Square brackets)**: Matches any **one character** inside the brackets.
   - Regex: `[aeiou]`
   - Matches: Any vowel like `"a"`, `"e"`, `"i"`, `"o"`, `"u"`
   - Does **not** match: `"b"`, `"z"`

2. **`-` (hyphen)**: Used inside square brackets to define a range of characters.
   - Regex: `[a-z]`
   - Matches: Any lowercase letter from `a` to `z`.
   - **Example**: `[0-9]` matches any digit from `0` to `9`.

3. **Predefined Character Classes**:
   - **`\d`**: Matches any **digit** (equivalent to `[0-9]`).
     - Regex: `\d{3}`
     - Matches: Any three digits like `"123"`, `"456"`
   - **`\w`**: Matches any **word character** (equivalent to `[a-zA-Z0-9_]`).
     - Regex: `\w+`
     - Matches: `"hello"`, `"world123"`, `"A_b"`
   - **`\s`**: Matches any **whitespace character** (spaces, tabs, line breaks).
     - Regex: `\s`
     - Matches: `" "` (a space), `"\t"` (a tab) -->


#### **Grouping and Alternation**

1. **Parentheses `()`**: Used to group part of the regex for applying quantifiers or capturing matches.
   - Regex: `(ab)+`
   - Matches: `"ab"`, `"abab"`, `"ababab"`
   - Does **not** match: `"a"`, `"b"`, `"aab"`

2. **Pipe `|` (Alternation)**: Acts like a logical OR, matching either of the patterns.
   - Regex: `cat|dog`
   - It looks for the entire word
   - Matches: `"cat"` or `"dog"`

#### Summary of Most-Used Regex Elements:

| **Regex Symbol** | **Meaning** |
| ---------------- | ----------- |
| `.`              | Any single character (except newline) |
| `*`              | Zero or more of the previous element |
| `+`              | One or more of the previous element |
| `?`              | Zero or one of the previous element |
| `{n}`            | Exactly `n` occurrences |
| `^`              | Start of a string |
| `$`              | End of a string |
| `\[\]`           | Character class (match any character inside) |
| `\d`             | Any digit (0-9) |
| `\w`             | Any word character (alphanumeric + underscore) |
| `\s`             | Any whitespace character |
| `|`              | Alternation (OR) |
| `()`             | Grouping |

---

### Example Use of `sed` with Regex:

Command:
```bash
sed 's/[0-9]/#/g'
```
Explanation:
- This will replace **all digits** (`\[0-9\]`) in the input with `#`(`\` is the escape character here).


```bash
ssh myserver journalctl
 | grep sshd
 | grep "Disconnected from"
 | sed -E 's/.*Disconnected from (invalid |authenticating )?user (.*) [^ ]+ port [0-9]+( \[preauth\])?$/\2/'
 | sort | uniq -c
 | sort -nk1,1 | tail -n10
 | awk '{print $2}' | paste -sd,
```

`sort -k 1,1`: The `-k` option specifies the sort key, which determines which part of the line should be used for sorting.

-  `1,1` means the sort is done based on the first field (column).
-  Fields are separated by whitespace by default.
-  `1,1` restricts the sorting to the first field only, and no other part of the line is used for sorting.
-  
`paste -sd`: This command can combine lines of input.
-  `-s`: The `-s` option tells paste to merge all the input lines into a single line (instead of pasting them side by side).
-  `-d,`: The `-d` option specifies the delimiter, which in this case is a comma (`,`). It tells paste to join the items using a comma.

## `awk`

**`awk`** is a powerful command-line tool used for text processing and data extraction in Unix/Linux environments. It operates on files or input streams, typically treating each line as a record, and each part of the line as a field. `awk` is ideal for extracting specific fields, performing operations on data, and formatting output.

### **Basic `awk` Command Format:**

```bash
awk 'pattern { action }' [file]
```

- **`pattern`**: The condition or pattern that determines which lines `awk` will process.
- **`action`**: The operation to perform on the lines that match the pattern.
- **`file`**: The input file (or input from stdin if no file is provided).


### **Basic Examples**:

#### 1. **Print Every Line of a File**:
```bash
awk '{ print $0 }' filename
```
This command prints every line of the file (`$0` refers to the entire line).

#### 2. **Print a Specific Field**:
```bash
awk '{ print $2 }' filename
```
This prints the second field (`$2`) of each line in the file.

#### Example Input (`example.txt`):
```
John 25 Manager
Jane 30 Developer
Tom 22 Designer
```

```bash
awk '{ print $1 }' example.txt
```

**Output**:
```
John
Jane
Tom
```
This prints only the first field (name) from each line.

---

### **Common `awk` Use Cases**:

#### 1. **Print Specific Fields**:
You can specify which fields (columns) to print using `$1`, `$2`, etc.

```bash
awk '{ print $1, $3 }' example.txt
```

**Output**:
```
John Manager
Jane Developer
Tom Designer
```

#### 2. **Specify a Field Separator**:
By default, `awk` assumes fields are separated by whitespace. You can change the field separator using the `-F` option.

Example with a CSV file:
```
John,25,Manager
Jane,30,Developer
Tom,22,Designer
```

To print the first and third fields of a CSV file:

```bash
awk -F',' '{ print $1, $3 }' example.csv
```

**Output**:
```
John Manager
Jane Developer
Tom Designer
```

Here, **`-F','`** tells `awk` to use a comma as the field separator.

---

#### 3. **Conditional Processing**:
You can apply conditions to control which lines are processed.

**Example**: Print lines where the second field (age) is greater than 25.

```bash
awk '$2 > 25 { print $1, $2 }' example.txt
```

**Output**:
```
Jane 30
```

This prints only the lines where the second field (age) is greater than 25.

---

#### 4. **Perform Arithmetic Operations**:
`awk` can perform arithmetic on fields.

**Example**: Add 10 to each person's age.

```bash
awk '{ print $1, $2 + 10 }' example.txt
```

**Output**:
```
John 35
Jane 40
Tom 32
```

---

#### 5. **Pattern Matching**:
You can use regular expressions to match patterns.

**Example**: Print lines that contain the word "Developer":

```bash
awk '/Developer/ { print $0 }' example.txt
```

**Output**:
```
Jane 30 Developer
```

You can use `awk` to process lines that match (or don't match) specific patterns.

---

### **Advanced Features of `awk`**:

#### 1. **BEGIN and END Blocks**:
`awk` allows you to define special actions at the start and end of processing.

- **BEGIN**: Executes before processing the input.
- **END**: Executes after processing all input.

**Example**: Calculate the sum of ages.

```bash
awk 'BEGIN { sum = 0 } { sum += $2 } END { print "Total age:", sum }' example.txt
```

**Output**:
```
Total age: 77
```

Here:
- The `BEGIN` block initializes the `sum` variable to 0.
- The main block `{ sum += $2 }` adds the second field (age) to the sum for each line.
- The `END` block prints the total after processing all lines.

---

#### 2. **Built-in Variables**:
`awk` has several built-in variables:

- **`NR`**: Current record number (line number).
- **`NF`**: Number of fields in the current record.
- **`$0`**: The entire line.

**Example**: Print each line with its line number.

```bash
awk '{ print NR, $0 }' example.txt
```

**Output**:
```
1 John 25 Manager
2 Jane 30 Developer
3 Tom 22 Designer
```

---

#### 3. **String Manipulation**:
`awk` provides functions to manipulate strings, like `length()`, `substr()`, `tolower()`, and `toupper()`.

**Example**: Print the length of the first field.

```bash
awk '{ print $1, length($1) }' example.txt
```

**Output**:
```
John 4
Jane 4
Tom 3
```

---

### **Summary of `awk` Usage**:

| **Command** | **Description** |
|-------------|-----------------|
| `awk '{ print $1 }' file` | Print the first field (column) of each line. |
| `awk -F',' '{ print $2 }' file` | Specify a field separator (comma in this case). |
| `awk '$2 > 25 { print $1 }' file` | Print the first field if the second field is greater than 25. |
| `awk 'BEGIN { action } { action } END { action }' file` | Use `BEGIN` and `END` blocks for initialization and final actions. |
| `awk '{ print NR, $0 }' file` | Print the line number along with the entire line. |

`awk` is a versatile tool for processing and extracting data from text files or input streams. It’s great for manipulating structured data, performing arithmetic, and applying conditions based on patterns.

## Exercises

https://regexone.com/lesson/introduction_abcs -> Great tutorial!

