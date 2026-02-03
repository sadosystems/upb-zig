"""Internal rules for building peglike."""

def make_shell_script(name, contents, out):
    contents = contents.replace("$", "$$")
    native.genrule(
        name = "gen_" + name,
        outs = [out],
        cmd = "(cat <<'HEREDOC'\n%s\nHEREDOC\n) > $@" % contents,
    )