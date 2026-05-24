module lsp;
import lsp::server;
import seali;

import std::collections::maybe;

struct CliArgs @Command({ .name = "c3_ls" })
{
	Maybe{String} stdlib_path   @Seali(arg(long, help = "The std path"));
	Maybe{String} compiler_path @Seali(arg(long, help = "Path to C3 compiler binary"));
	uint diagnostics_delay      @Seali(arg(long, help = "delay", default_value = 0));
}

fn int main(String[] args)
{
	CliArgs cli = seali::parse(CliArgs, args)!!;
	server::start(cli);
	return 0;
}