#import "@tola/source:0.0.0": tola-meta

#tola-meta((
  title: "[Missing Semester 04] Lecture 4",
  date: "2024-10-15",
  tags: ("Course", "The Missing Semester"),
  weight: 10,
  series: "Missing Semester",
))

```bash
# journalctl run remotely, grep run locally
ssh myserver journalctl | grep sshd
# both commands run remotely
ssh myserver "journalctl | grep sshd"
```

= `sed`
`sed` (Stream Editor) is a powerful command-line tool in Unix/Linux that is used for parsing and transforming text, typically used for finding, replacing, or deleting content in a file or input stream.

Common sed Commands:

- #strong[Substitution] (`s`):

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

This replaces the first occurrence of the word \"apple\" with \"orange\" on each line.

- #strong[Delete] (`d`):

```bash
sed '/pattern/d' file
```

Deletes all lines that match a given pattern.

- #strong[Print] (`p`):

```bash
sed -n 'p'
```

Prints lines (used with -n to suppress default behavior).

Example:

```bash
# This will print lines 2 and 3
sed -n '2,3p' example.txt
```

== #strong[Basic, Common, and Most-Used Regular Expressions (Regex)]
=== #strong[Basic Regex Symbols and Their Meaning]
Quantifiers specify how many instances of a character, group, or character class must be present in the input for a match.

+ #strong[`.` (dot)]: Matches #strong[any single character] except a newline.

  - Regex: `a.b`
  - Matches: `"a1b"`, `"axb"`, `"a b"`
  - Does #strong[not] match: `"ab"`, `"a\nb"`

+ #strong[`*` (asterisk)]: Matches #strong[zero or more] occurrences of the preceding character.

  - Regex: `ca*t`
  - Matches: `"ct"`, `"cat"`, `"caat"`, `"caaaaat"`

+ #strong[`+` (plus)]: Matches #strong[one or more] occurrences of the preceding character.

  - Regex: `ca+t`
  - Matches: `"cat"`, `"caat"`
  - Does #strong[not] match: `"ct"`

+ #strong[`?` (question mark)]: Matches #strong[zero or one] occurrence of the preceding character.

  - Regex: `ca?t`
  - Matches: `"cat"`, `"ct"`
  - Does #strong[not] match: `"caat"`

+ #strong[`{}` (braces)]: Matches a specific number of occurrences.

  - `{n}`: Exactly `n` occurrences.
    - Regex: `a{3}`
    - Matches: `"aaa"`
  - `{n,}`: At least `n` occurrences.
    - Regex: `a{2,}`
    - Matches: `"aa"`, `"aaa"`, `"aaaa"`
  - `{n,m}`: Between `n` and `m` occurrences.
    - Regex: `a{2,4}`
    - Matches: `"aa"`, `"aaa"`, `"aaaa"`
    - Does #strong[not] match: `"a"`, `"aaaaa"`

=== #strong[Anchors] (for Position Matching)
Anchors don't match characters, but rather positions in the string.

+ #strong[`^` (caret)]: Matches the #strong[start] of a string.

  - Regex: `^hello`
  - Matches: `"hello world"`
  - Does #strong[not] match: `"world hello"`

+ #strong[`$` (dollar sign)]: Matches the #strong[end] of a string.

  - Regex: `world$`
  - Matches: `"hello world"`
  - Does #strong[not] match: `"world hello"`

+ #strong[`\b` (word boundary)]: Matches the position between a word character (`\w`) and a non-word character.

  - Regex: `\bcat\b`
  - Matches: `"cat is here"`, `"I have a cat"`
  - Does #strong[not] match: `"caterpillar"`, `"catch"`

=== #strong[Grouping and Alternation]
+ #strong[Parentheses `()`]: Used to group part of the regex for applying quantifiers or capturing matches.

  - Regex: `(ab)+`
  - Matches: `"ab"`, `"abab"`, `"ababab"`
  - Does #strong[not] match: `"a"`, `"b"`, `"aab"`

+ #strong[Pipe `|` (Alternation)]: Acts like a logical OR, matching either of the patterns.

  - Regex: `cat|dog`
  - It looks for the entire word
  - Matches: `"cat"` or `"dog"`

=== Summary of Most-Used Regex Elements
#figure(
  table(
    columns: 2,
    align: (auto,auto,),
    table.header([#strong[Regex Symbol]], [#strong[Meaning]],),
    table.hline(),
    [`.`], [Any single character (except newline)],
    [`*`], [Zero or more of the previous element],
    [`+`], [One or more of the previous element],
    [`?`], [Zero or one of the previous element],
    [`{n}`], [Exactly `n` occurrences],
    [`^`], [Start of a string],
    [`$`], [End of a string],
    [`\[\]`], [Character class (match any character inside)],
    [`\d`], [Any digit (0-9)],
    [`\w`], [Any word character (alphanumeric + underscore)],
    [`\s`], [Any whitespace character],
    [\`], [\`],
    [`()`], [Grouping],
  )
  , kind: table
  )

#html.hr()
== Example Use of `sed` with Regex
Command:

```bash
sed 's/[0-9]/#/g'
```

Explanation:

- This will replace #strong[all digits] (`\[0-9\]`) in the input with `#`\(`\` is the escape character here).

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

- `1,1` means the sort is done based on the first field (column).
- Fields are separated by whitespace by default.
- `1,1` restricts the sorting to the first field only, and no other part of the line is used for sorting.
-

`paste -sd`: This command can combine lines of input.

- `-s`: The `-s` option tells paste to merge all the input lines into a single line (instead of pasting them side by side).
- `-d,`: The `-d` option specifies the delimiter, which in this case is a comma (`,`). It tells paste to join the items using a comma.

= `awk`
#strong[`awk`] is a powerful command-line tool used for text processing and data extraction in Unix/Linux environments. It operates on files or input streams, typically treating each line as a record, and each part of the line as a field. `awk` is ideal for extracting specific fields, performing operations on data, and formatting output.

== #strong[Basic `awk` Command Format:]
```bash
awk 'pattern { action }' [file]
```

- #strong[`pattern`]: The condition or pattern that determines which lines `awk` will process.
- #strong[`action`]: The operation to perform on the lines that match the pattern.
- #strong[`file`]: The input file (or input from stdin if no file is provided).

== #strong[Basic Examples]
=== 1. #strong[Print Every Line of a File]
```bash
awk '{ print $0 }' filename
```

This command prints every line of the file (`$0` refers to the entire line).

=== 2. #strong[Print a Specific Field]
```bash
awk '{ print $2 }' filename
```

This prints the second field (`$2`) of each line in the file.

=== Example Input (`example.txt`)
```text
John 25 Manager
Jane 30 Developer
Tom 22 Designer
```

```bash
awk '{ print $1 }' example.txt
```

#strong[Output]:

```text
John
Jane
Tom
```

This prints only the first field (name) from each line.

#html.hr()
== #strong[Common `awk` Use Cases]
=== 1. #strong[Print Specific Fields]
You can specify which fields (columns) to print using `$1`, `$2`, etc.

```bash
awk '{ print $1, $3 }' example.txt
```

#strong[Output]:

```text
John Manager
Jane Developer
Tom Designer
```

=== 2. #strong[Specify a Field Separator]
By default, `awk` assumes fields are separated by whitespace. You can change the field separator using the `-F` option.

Example with a CSV file:

```text
John,25,Manager
Jane,30,Developer
Tom,22,Designer
```

To print the first and third fields of a CSV file:

```bash
awk -F',' '{ print $1, $3 }' example.csv
```

#strong[Output]:

```text
John Manager
Jane Developer
Tom Designer
```

Here, #strong[`-F','`] tells `awk` to use a comma as the field separator.

#html.hr()
=== 3. #strong[Conditional Processing]
You can apply conditions to control which lines are processed.

#strong[Example]: Print lines where the second field (age) is greater than 25.

```bash
awk '$2 > 25 { print $1, $2 }' example.txt
```

#strong[Output]:

```text
Jane 30
```

This prints only the lines where the second field (age) is greater than 25.

#html.hr()
=== 4. #strong[Perform Arithmetic Operations]
`awk` can perform arithmetic on fields.

#strong[Example]: Add 10 to each person\'s age.

```bash
awk '{ print $1, $2 + 10 }' example.txt
```

#strong[Output]:

```text
John 35
Jane 40
Tom 32
```

#html.hr()
=== 5. #strong[Pattern Matching]
You can use regular expressions to match patterns.

#strong[Example]: Print lines that contain the word \"Developer\":

```bash
awk '/Developer/ { print $0 }' example.txt
```

#strong[Output]:

```text
Jane 30 Developer
```

You can use `awk` to process lines that match (or don\'t match) specific patterns.

#html.hr()
== #strong[Advanced Features of `awk`]
=== 1. #strong[BEGIN and END Blocks]
`awk` allows you to define special actions at the start and end of processing.

- #strong[BEGIN]: Executes before processing the input.
- #strong[END]: Executes after processing all input.

#strong[Example]: Calculate the sum of ages.

```bash
awk 'BEGIN { sum = 0 } { sum += $2 } END { print "Total age:", sum }' example.txt
```

#strong[Output]:

```text
Total age: 77
```

Here:

- The `BEGIN` block initializes the `sum` variable to 0.
- The main block `{ sum += $2 }` adds the second field (age) to the sum for each line.
- The `END` block prints the total after processing all lines.

#html.hr()
=== 2. #strong[Built-in Variables]
`awk` has several built-in variables:

- #strong[`NR`]: Current record number (line number).
- #strong[`NF`]: Number of fields in the current record.
- #strong[`$0`]: The entire line.

#strong[Example]: Print each line with its line number.

```bash
awk '{ print NR, $0 }' example.txt
```

#strong[Output]:

```text
1 John 25 Manager
2 Jane 30 Developer
3 Tom 22 Designer
```

#html.hr()
=== 3. #strong[String Manipulation]
`awk` provides functions to manipulate strings, like `length()`, `substr()`, `tolower()`, and `toupper()`.

#strong[Example]: Print the length of the first field.

```bash
awk '{ print $1, length($1) }' example.txt
```

#strong[Output]:

```text
John 4
Jane 4
Tom 3
```

#html.hr()
== #strong[Summary of `awk` Usage]
#figure(
  table(
    columns: 2,
    align: (auto,auto,),
    table.header([#strong[Command]], [#strong[Description]],),
    table.hline(),
    [`awk '{ print $1 }' file`], [Print the first field (column) of each line.],
    [`awk -F',' '{ print $2 }' file`], [Specify a field separator (comma in this case).],
    [`awk '$2 > 25 { print $1 }' file`], [Print the first field if the second field is greater than 25.],
    [`awk 'BEGIN { action } { action } END { action }' file`], [Use `BEGIN` and `END` blocks for initialization and final actions.],
    [`awk '{ print NR, $0 }' file`], [Print the line number along with the entire line.],
  )
  , kind: table
  )

`awk` is a versatile tool for processing and extracting data from text files or input streams. It's great for manipulating structured data, performing arithmetic, and applying conditions based on patterns.

= Exercises
#link("https://regexone.com/lesson/introduction_abcs") -\> Great tutorial!
