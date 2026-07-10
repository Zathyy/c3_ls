module lsp;
import lsp::server;

import std::collections::maybe;

import std::os::argparse;
import std::io;

struct CliArgs
{
	String stdlib_path;
	String compiler_path;
	String log_path;
	String cache_path;
	LogLevel log_level;
	uint diagnostics_delay;
	bool send_crash_reports;
}

fn int main(String[] args)
{
	CliArgs cli;

	sz? result = argparse::@parse(args,
		"",  "stdlib-path", "stdlib path",                    &cli.stdlib_path,
		"",  "compiler-path", "Path to c3c executable",       &cli.compiler_path,
		"",  "log-path", "Path to log file",           &cli.log_path,
		"",  "cache-path", "Override where the cache files are stored",         &cli.cache_path,
		"",  "log-level", "On which level to log to stderr",          &cli.log_level,                     
		"",  "diagnostics-delay", "delay before doing diagnosting",  &cli.diagnostics_delay,                     
		"",  "send-crash-reports", "Send crash reports", &cli.send_crash_reports,                     
	);

	if (catch err = result)
	{
		if (err == argparse::HELP_REQUESTED) return 0;
		io::eprintfn("Command-line error: %s", err);
		return 1;
	}

	server::start(cli);
	return 0;
}
