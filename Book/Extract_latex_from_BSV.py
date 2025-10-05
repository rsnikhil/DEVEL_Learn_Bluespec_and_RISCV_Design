#!/usr/bin/env  python3

usage_line = (
    "Usage:    {0}    <root-dir-for-BSV-sources>    <dest_dir>\n")

help_lines = (
    "  Recursively traverses all files in <root-dir> and its subdirectories.\n"
    "  For each source file with '.bsv' extension, locates lines containing:\n"
    "      \\blatex{tag},\n"
    "      \\elatex{tag} or \\elatex{...tag},\n"
    "  and outputs all intervening lines (trimming leading and trailing blank lines)\n"
    "  to a file named 'tag.tex' in <dest_dir>,\n"
    "  bracketed by \begin{Verbatim} and \end{Verbatim} lines.\n"
    "  FOr \\elatex{...tag} appends a '... more ...' line at the end."
)

import sys
import os
import stat
import fileinput

# ================================================================

def main (argv = None):
    if ((len (argv) <= 1) or
        (argv [1] == '-h') or (argv [1] == '--help') or
        (len (argv) != 3)):
        sys.stdout.write (usage_line.format (argv [0]))
        sys.stdout.write ("\n")
        sys.stdout.write (help_lines)
        sys.stdout.write ("\n")
        return 0

    path      = os.path.abspath (os.path.normpath (argv [1]))
    dest_path = os.path.abspath (os.path.normpath (argv [2]))
    max_level = 3
    traverse (path, max_level, 0, path, dest_path)

def traverse (orig_path, max_level, level, path, dest_path):
    st = os.stat (path)
    is_dir = stat.S_ISDIR (st.st_mode)
    is_reg = stat.S_ISREG (st.st_mode)
    do_foreachfile_function (orig_path, level, is_dir, is_reg, path, dest_path)
    if is_dir and level < max_level:
        with os.scandir (path) as it:
            for entry in it:
                traverse (orig_path, max_level, level + 1, path + "/" + entry.name, dest_path)
    return 0

# ================================================================
# This function is applied to every path in the
# recursive traversal

def do_foreachfile_function (orig_path, level, is_dir, is_reg, path, dest_path):
    prefix = ""
    for j in range (level): prefix = "  " + prefix

    # directories
    if is_dir:
        # print ("%s%d dir %s" % (prefix, level, path))
        pass

    # regular files
    elif is_reg:
        dirname  = os.path.dirname (path)
        basename = os.path.basename (path)
        # print ("%s%d %s" % (prefix, level, path))
        do_regular_file_function (orig_path, level, dirname, basename, dest_path)

    # other files
    else:
        print ("%s%d Unknown file type: %s" % (prefix, level, os.path.basename (path)))

# ================================================================
# Process each text file, extracting lines between \blatex and \elatex tags

def do_regular_file_function (orig_path, level, dirname, basename, dest_path):
    # Ignore file if filename does not end in ".bsv" or ".bsvi" (BSV sources)
    if not (basename.endswith (".bsv") or basename.endswith (".bsvi")):
        return

    filename     = os.path.join (dirname, basename)
    rel_filename = filename.replace (orig_path, "", 1).replace ("_", "\\_")
    if rel_filename.startswith ("/"):
        rel_filename = rel_filename [1:]

    # For debugging only
    prefix = ""
    for j in range (level): prefix = "  " + prefix
    # sys.stdout.write ("{0}{1} ACTION:    {2}\n".format (prefix, level, filename))

    IDLE       = 0
    EXTRACTING = 1

    state      = IDLE
    linenum    = 0
    for line in fileinput.input (filename):
        line = line.rstrip ()
        linenum    = linenum + 1
        blatex     = find_keyword (filename, linenum, line, "\\blatex")
        belide     = find_keyword (filename, linenum, line, "\\belide")
        eelide     = find_keyword (filename, linenum, line, "\\eelide")
        elatex     = find_keyword (filename, linenum, line, "\\elatex")
        blank_line = (line == "") or line.isspace()

        if (state == IDLE):
            if (blatex == None):
                pass
            else:
                current_tag = blatex [1]
                fd = open (os.path.join (dest_path, blatex [1] + ".tex"), 'w')
                sys.stdout.write ("% from file '{0}' line {1} => {2}.tex\n".
                                  format (basename, linenum, current_tag))
                fd.write ("% from file '{0}' line {1}  tag {2}\n".
                          format (basename, linenum, current_tag))
                # fd.write ("{\\small\n")
                fd.write ("\\begin{Verbatim}")
                fd.write ("[frame=single, numbers=left, label={0}: line {1} ...]\n"
                          .format(rel_filename, linenum))
                state         = EXTRACTING
                eliding       = False
                n_blank_lines = 0
                if (blatex [0] != ""):
                    fd.write ("{0}\n".format (blatex [0]))
        else:
            assert (state == EXTRACTING)
            if eliding:
                if (eelide != None): eliding = False
            elif (belide != None):
                eliding = True
                indent  = ""
                if belide [1].isdecimal ():
                    indent_n = int (belide [1])
                else:
                    indent_n = 3
                for j in range (indent_n):
                    indent += " "
                fd.write ("{0}...\n".format (indent))
            elif (elatex != None):
                # Finished extract
                match_tag = (current_tag == elatex [1])
                if not match_tag:
                    sys.stdout.write ("WARNING: unmatched tags: {0} and {1}\n".
                                      format (current_tag, elatex [1]))
                if (elatex [0] != ""):
                    write_n_blank_lines (fd, n_blank_lines)
                    fd.write ("{0}\n".format (elatex [0]))
                fd.write ("\\end{Verbatim}\n")
                # fd.write ("}\n")
                fd.close ()
                state = IDLE
            else:
                if blank_line:
                    n_blank_lines += 1
                else:
                    # Normal extracted line
                    write_n_blank_lines (fd, n_blank_lines)
                    fd.write ("{0}\n".format (line))
                    n_blank_lines = 0

# Finds \keyword or \keyword{tag} in line.  Returns: None or (line upto \keyword, tag)

def find_keyword (filename, linenum, line, keyword):
    j1 = line.find (keyword)
    if j1 == -1: return None

    j2 = line.find ("//")
    if j2 == -1:
        sys.stdout.write ("WARNING: {0} is not in a comment?\n".format (keyword))
        line_upto_keyword = line [:j1]
    else:
        line_upto_keyword = line [:j2]
    line_upto_keyword = line_upto_keyword.rstrip()

    # line2 is from just past the keyword and before the '{' if any
    line2 = line [j1 + len (keyword) : ].lstrip()
    if not line2.startswith ("{"):
        return (line_upto_keyword, "")

    # line2 is from just past '{'
    line3 = line2 [1 : ].lstrip ()
    j3    = line3.find ("}")
    if j3 == -1:
        sys.stdout.write ("WARNING: after {0}'{' there is no '}'; ignoring\n".format (keyword))
        sys.stdout.write ("    File {0}, Line num {1}\n".format (filename, linenum))
        sys.stdout.write ("    Line:{0}".format (line))
        return None

    tag = line3 [:j3].rstrip()

    return (line_upto_keyword, tag)

# Writes n blank lines that are now known not to be trailing blank lines

def write_n_blank_lines (fd, n):
    for j in range (n):
        fd.write ("\n")

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
