module lsp::core::logger;

import lsp::msg_handler::log_message;
import lsp::server;

import std::io;
import std::time;
import std::collections::list;

File file;
LogPriority priority_level;

fn void init()
{
	priority_level = to_category(server::log_level);

	if (!server::log_path) return;
	if (catch err = @try(file, file::open(server::log_path, "w")))
	{
		log::error("Failed to open file: %s (%s)", err, server::log_path);
	}
	log::info("Logging to file: %s", server::log_path);
}

fn void flush()
{
	if (!file.file) return;
	(void)file.flush();
}

fn void close()
{
	if (!file.file) return;
	file.close();
}

struct LspLogger (Logger)
{
	void* dummy;
}

fn MessageType to_type(LogPriority priority) @local 
{
	switch (priority)
	{
		case CRITICAL: 
		case ERROR:
			return ERROR;
		case WARN: return WARNING;
		case INFO: return INFO;
		default: return LOG;
	}
}

fn LogPriority to_category(LogLevel level) @local 
{
	switch (level)
	{
		case DEBUG: return DEBUG;
		case INFO: return INFO;
		case WARN: return WARN;
		default:
			return ERROR;
	}
}

fn void LspLogger.log(&self, LogPriority priority, LogCategory category, LogTag tag, String file, String function, int line, String fmt, any[] args) @dynamic
{
	@stack_mem(256 + 64; Allocator mem)
	{
		DString str;
		str.init(mem, 256);
		str.appendf(fmt, ...args);
		TzDateTime time = datetime::now().to_local();
		$if log::FULL_LOG:
		if (logger::file.file)
		{
			(void)io::fprintfn(&logger::file, "[%02d:%02d:%02d:%04d] %s:%d [%s] %s", time.hour, time.min, time.sec, (time.usec / 1000), file, line, priority, str);
			(void)logger::file.flush(); // flush everytime to capture crashes
		}
		if (priority < priority_level) return;
		io::eprintfn("[%02d:%02d:%02d:%04d] %s:%d [%s] %s", time.hour, time.min, time.sec, (time.usec / 1000), file, line, priority, str);
		$else
		if (logger::file.file)
		{
			(void)io::fprintfn(&logger::file, "[%02d:%02d:%02d:%04d] [%s] %s", time.hour, time.min, time.sec, (time.usec / 1000), priority, str);
			(void)logger::file.flush(); // flush everytime to capture crashes
		}
		if (priority < priority_level) return;
		io::eprintfn("[%02d:%02d:%02d:%04d] [%s] %s", time.hour, time.min, time.sec, (time.usec / 1000), priority, str);
		$endif
	};
}