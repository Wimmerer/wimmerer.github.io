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