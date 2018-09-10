@testset "Find blocks" begin
    st = raw"""
        some markdown then `code` and
        @@dname block @@
        then maybe an escape
        ~~~
        escape block
        ~~~
        and done {target} done.
        """ * JuDoc.EOS
    tokens = JuDoc.find_tokens(st, JuDoc.MD_TOKENS, JuDoc.MD_1C_TOKENS)
    tokens = JuDoc.deactivate_xblocks(tokens, JuDoc.MD_EXTRACT)
    bblocks, tokens = JuDoc.find_md_bblocks(tokens)
    xblocks, tokens = JuDoc.find_md_xblocks(tokens)

    @test bblocks[1].ss == "{target}"
    @test xblocks[1].ss == "`code`"
    @test xblocks[2].ss == "@@dname"
    @test xblocks[3].ss == "@@"
    @test xblocks[4].ss == "~~~\nescape block\n~~~"
end


@testset "Lx defs+coms" begin
    st = raw"""
        \newcommand{\E}[1]{\mathbb E\left[#1\right]}blah de blah
        ~~~
        escape b1
        ~~~
        \newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}
        \newcommand{\R}{\mathbb R}
        Then something like
        \eqa{ \E{f(X)} \in \R &\text{if}& f:\R\maptso\R }
        and we could try to show latex:
        ```latex
        \newcommand{\brol}{\mathbb B}
        ```
        """ * JuDoc.EOS
    tokens = JuDoc.find_tokens(st, JuDoc.MD_TOKENS, JuDoc.MD_1C_TOKENS)
    tokens = JuDoc.deactivate_xblocks(tokens, JuDoc.MD_EXTRACT)
    bblocks, tokens = JuDoc.find_md_bblocks(tokens)
    lxdefs, tokens = JuDoc.find_md_lxdefs(tokens, bblocks)

    @test lxdefs[1].name == "\\E"
    @test lxdefs[1].narg == 1
    @test lxdefs[1].def == "\\mathbb E\\left[#1\\right]"
    @test lxdefs[2].name == "\\eqa"
    @test lxdefs[2].narg == 1
    @test lxdefs[2].def == "\\begin{eqnarray}#1\\end{eqnarray}"
    @test lxdefs[3].name == "\\R"
    @test lxdefs[3].narg == 0
    @test lxdefs[3].def == "\\mathbb R"

    xblocks, tokens = JuDoc.find_md_xblocks(tokens)

    @test xblocks[1].name == :ESCAPE
    @test xblocks[2].name == :CODE

    lxcoms, tokens = JuDoc.find_md_lxcoms(tokens, lxdefs, bblocks)

    @test lxcoms[1].ss == "\\eqa{ \\E{f(X)} \\in \\R &\\text{if}& f:\\R\\maptso\\R }"
    lxd = getindex(lxcoms[1].lxdef)
    @test lxd.name == "\\eqa"
end


@testset "Lxdefs 2" begin
    st = raw"""
        \newcommand{\com}{blah}
        \newcommand{\comb}[ 2]{hello #1 #2}
        """ * JuDoc.EOS
    tokens = JuDoc.find_tokens(st, JuDoc.MD_TOKENS, JuDoc.MD_1C_TOKENS)
    tokens = JuDoc.deactivate_xblocks(tokens, JuDoc.MD_EXTRACT)
    bblocks, tokens = JuDoc.find_md_bblocks(tokens)
    lxdefs, tokens = JuDoc.find_md_lxdefs(tokens, bblocks)
    @test lxdefs[1].name == "\\com"
    @test lxdefs[1].narg == 0
    @test lxdefs[1].def == "blah"
    @test lxdefs[2].name == "\\comb"
    @test lxdefs[2].narg == 2
    @test lxdefs[2].def == "hello #1 #2"
end


@testset "Lxcoms 2" begin
    st = raw"""
        \newcommand{\com}{HH}
        \newcommand{\comb}[1]{HH#1HH}
        Blah \com and \comb{blah} etc
        ```julia
        f(x) = x^2
        ```
        etc \comb{blah} then maybe
        @@adiv inner part @@ final.
        """ * JuDoc.EOS

    # Tokenization and Markdown conversion
    tokens = JuDoc.find_tokens(st, JuDoc.MD_TOKENS, JuDoc.MD_1C_TOKENS)
    tokens = JuDoc.deactivate_xblocks(tokens, JuDoc.MD_EXTRACT)
    bblocks, tokens = JuDoc.find_md_bblocks(tokens)
    lxdefs, tokens = JuDoc.find_md_lxdefs(tokens, bblocks)
    xblocks, tokens = JuDoc.find_md_xblocks(tokens)
    lxcoms, tokens = JuDoc.find_md_lxcoms(tokens, lxdefs, bblocks)
    tokens = filter(τ -> τ.name != :LINE_RETURN, tokens)

    @test lxcoms[1].ss == "\\com"
    @test lxcoms[2].ss == "\\comb{blah}"

    @test xblocks[1].name == :CODE
    @test xblocks[2].name == :DIV_OPEN
    @test xblocks[3].name == :DIV_CLOSE
end


@testset "lxcoms3" begin
    st = raw"""
        text A1 \newcommand{\com}{blah}text A2 \com and
        ~~~
        escape B1
        ~~~
        \newcommand{\comb}[ 1]{\mathrm{#1}} text C1 $\comb{b}$ text C2
        \newcommand{\comc}[ 2]{part1:#1 and part2:#2} then \comc{AA}{BB}.
        """ * JuDoc.EOS

    tokens = JuDoc.find_tokens(st, JuDoc.MD_TOKENS, JuDoc.MD_1C_TOKENS)
    tokens = JuDoc.deactivate_xblocks(tokens, JuDoc.MD_EXTRACT)
    bblocks, tokens = JuDoc.find_md_bblocks(tokens)
    lxdefs, tokens = JuDoc.find_md_lxdefs(tokens, bblocks)
    xblocks, tokens = JuDoc.find_md_xblocks(tokens)

    @test lxdefs[1].name == "\\com" && lxdefs[1].narg == 0 &&  lxdefs[1].def == "blah"
    @test lxdefs[2].name == "\\comb" && lxdefs[2].narg == 1 && lxdefs[2].def == "\\mathrm{#1}"
    @test lxdefs[3].name == "\\comc" && lxdefs[3].narg == 2 && lxdefs[3].def == "part1:#1 and part2:#2"
    @test xblocks[1].name == :ESCAPE && xblocks[1].ss == "~~~\nescape B1\n~~~"

    lxcoms, tokens = JuDoc.find_md_lxcoms(tokens, lxdefs, bblocks)

    @test lxcoms[1].ss == "\\com" && JuDoc.getdef(lxcoms[1]) == "blah"
    @test lxcoms[2].ss == "\\comc{AA}{BB}"
end