function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

"""
Adapted from @rmsrosa on GitHub
"""
function hfun_blogposts()
    curyear = year(Dates.today())
    io = IOBuffer()
    for year in curyear:-1:2022
        ys = "$year"
        year < curyear && write(io, "\n**$year**\n")
        for month in 12:-1:1
            ms = "0"^(month < 10) * "$month"
            base = joinpath("blog", ys, ms)
            isdir(base) || continue
            posts = filter!(p -> endswith(p, ".md"), readdir(base))
            days  = zeros(Int, length(posts))
            lines = Vector{String}(undef, length(posts))
            for (i, post) in enumerate(posts)
                ps  = splitext(post)[1]
                url = "/blog/$ys/$ms/$ps/"
                surl = strip(url, '/')
                title = pagevar(surl, :title)
                pubdate = pagevar(surl, :published)
                if isnothing(pubdate)
                    rawdate = Date(year, month, 1)
                    days[i] = 1
                else
                    rawdate = Date(pubdate, dateformat"U d Y")
                    days[i] = day(rawdate)
                end
                date = Dates.format(rawdate, "d U, YYYY")
                lines[i] = "\n[$title]($url)\n$date\n"
            end
            # sort by day
            foreach(line -> write(io, line), lines[sortperm(days, rev=true)])
        end
    end
    # markdown conversion adds `<p>` beginning and end but
    # we want to  avoid this to avoid an empty separator
    r = "<div class=bloglist>\n" * 
        Franklin.fd2html(String(take!(io)), internal=true) * 
        "\n</div>\n"
    return r
end

function stringmime(m, x)
    open("/tmp/foo", "w") do io
        show(io, m, x)
    end 
    sprint(io->show(io, m, x))
end

const mime_renderers = [
    MIME("text/latex") => (x,m) -> stringmime(m, x),
    MIME("text/markdown") => (x,m) -> stringmime(m, x),
    MIME("text/html") => (x,m) -> "~~~$(stringmime(m, x))~~~",
    MIME("image/svg+xml") => (x,m) -> "~~~$(stringmime(m, x))~~~",
    MIME("image/png") => (x,m) -> "cant render png yet",
    MIME("image/jpeg") => (x,m) -> "cant render jpeg yet",
    MIME("text/plain") => (x,m) -> "`$x`",
]

function print_bestmime(x)
    if x === nothing
        return print()
    end
    for (m, f) in mime_renderers
        if showable(m, x)
            print(f(x, m))
            return
        end
    end
    print("`could not render the result`")
end

function repl_cell(ex, hide_output)
    s = """~~~
    <div class="julia-prompt">julia&gt; </div>
    ~~~```julia:repl-cell
    res = begin # hide
    $ex
    end # hide
    Franklin.utils_module().print_bestmime(res) # hide
    ```
    """
    if !hide_output
        s *= """~~~<div class="cell-output">~~~\\textoutput{repl-cell}~~~</div>~~~"""
    end
    s
end

function lx_repl(com, _) # the signature must look like this
    # leave this first line, it extracts the content of the brace
    content = Franklin.content(com.braces[1])
    # dumb way to recover stuff
    lines = split(content, "\n")
    cells = join([repl_cell(l, endswith(strip(l), ";"))  for l in lines if !isempty(strip(l)) ], "\n")
    str = """~~~<div class="repl-block">~~~$cells~~~</div>~~~"""
    print(str)
    str
end