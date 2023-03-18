# phut

A command line interface to post, share and retrieve pastes using the
https://paste.sr.ht API. `phut` is a POSIX shell script and has only been tested
on Linux. It was specifically developed as a piece of my personal development
environment (which uses Alpine Linux as a base).

## Install

```sh
pnpm add --global phut
```

<details><summary>npm</summary><p>

```sh
npm install --global phut
```

</p></details>
<details><summary>yarn</summary><p>

```sh
yarn global add phut
```

</p></details>
<details><summary>curl</summary><p>

```sh
curl -o ~/.local/bin/phut https://git.sr.ht/~rasch/phut/blob/main/phut.sh
chmod +x ~/.local/bin/phut
```

</p></details>

## Usage

```txt
phut [options] [FILE] ...
... | phut [options] [FILENAME]
```

By default, `phut` creates a new paste. Using the `-d` option will delete a
paste, the `-l` option will list pastes, the `-r` option will print a paste
blob/file to stdout and `-s` will save the paste blob/file in the current
working directory.

### Options

**`-p`**: Set visibility to private.

**`-u`**: Set visibility to unlisted.

**`-n`**: Don't attach FILE names to blobs.

**`-e`**: Encrypt FILEs with gpg.

**`-l`**: List all pastes (and attached blobs).

**`-r`** *`BLOB`*: Print BLOB to stdout.

**`-s`** *`PASTE`*: Save all blobs from PASTE in current directory.

**`-d`** *`PASTE`*: Delete PASTE (and all of the attached blobs/files).

**`-j`**: Output JSON.

**`-a`**: Output ASCII.

**`-A`**: Disable ANSI escapes.

**`-N`**: Disable Nerd Font (icons).

**`-q`**: Be less verbose.

**`-h`**: Show this help menu.

### Create a paste

```txt
phut [-p|-u] [-n] [-e] [-j|-q] [-a|-N] [-A] <FILE ...>
```

Creating a new public paste doesn't require any options and the only arguments
that it takes are the files to attach. The options `-p` or `-u` can be used to
make the paste private or unlisted, respectively. By default, the basename of
the file (without the directory) is used as the file name. Use the `-n` option
to disable attaching the name to the file (the name will be `null` in the file
listing). To encrypt (using `gpg --armor --symmetric`) use the `-e` option.
On success, a file tree representing the paste and attached blobs is printed to
stdout. Alternatively, the response can be displayed as the original JSON sent
from paste.sr.ht by using the `-j` option. To print just the URLs of the blobs,
use the `-q` option. The `-q` flag is useful here for quickly sharing files. The
rest of the options `-a` (ascii output), `-N` (no nerd font) and `-A` (no ansi)
are available to disable unicode in the UI, disable nerd fonts, or disable ANSI
escape sequences (color, bold, italics).

```sh
# create a new public paste with three files/blobs attached
phut file1.txt file2.js file3.md

# create a new private paste with no name and encrypt with gpg
phut -pen file.txt

# create a new unlisted encrypted paste with a directory and display the URL
# only (compresses the directory first using tar and gzip)
phut -ueq directory
```

### Delete a paste

```txt
phut -d [-a|-N] [-A] [-q] <PASTE>
```

To delete a PASTE and all of the attached blobs (files) use the `-d` option. The
blobs attached to the paste can't be deleted individually, so the positional
argument must be the SHA1 id of the paste. Only one paste can be deleted at a
time. The options `-a` (ascii output), `-A` (no ansi), `-N` (no nerd font) and
`-q` (quiet) can all be used with the `-d` (delete) option.

```sh
phut -d aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
```

### List pastes

```txt
phut -l [-p|-u] [-n] [-e] [-j|-q] [-a|-N] [-A]
```

Print the list of pastes to stdout. The options `-p`, `-u`, `-n` and `-e` act as
filters to show only private, unlisted, null named or encrypted pastes. The `-q`
option will print a newline separated list with a URL and filename for each
blob. To get the original JSON response, use the `-j` option. The options `-a`
(ascii output), `-A` (no ansi) and `-N` (no nerd font) are also available to
adjust the output.

```sh
# print a tree representation of all pastes
phut -l

# print the JSON request filtered to show only private pastes
phut -ljp
```

### Read blob (file)

```txt
phut -r <BLOB>
```

To print a blob (file) to stdout, use the `-r` option along with the SHA1 id of
the blob (file) to print.

```sh
phut -r aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
```

### Save blob (file)

```txt
phut -s [-q] [-a|-N] [-A] <PASTE>
```

Save all the blobs (files) from the PASTE in the current working directory.

## Tips & Tricks

### Quickly share a file with a link

```sh
phut -q file.txt | xclip
```

### Move file to new paste with a different filename

```sh
phut -r aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d | phut new-name
```

### Decrypt an encrypted blob

```sh
phut -r aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d | gpg -q
```

### Run a paste blob (file) as a shell script with[out] args

<dl>
  <dt>⚠️ WARNING</dt>
  <dd>
    Running a script this way is dangerous if it doesn't belong to you. Even if
    it does, there is always a chance that it has been compromised.
  </dd>
</dl>

```sh
phut -r dc2cb4d5ac2a8648cb28253eedd9696852389f0f | sh -s -- 2023 2027
phut -r 81580be9992b784cc3b94178dc7366eccec68b62 | sh
```
