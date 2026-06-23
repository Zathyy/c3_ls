module lsp::logger;

import lsp::msg_handler::log_message;
import lsp::server;

import std::io;

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

fn void LspLogger.log(&self, LogPriority priority, LogCategory category, LogTag tag, String file, String function, int line, String fmt, any[] args) @dynamic
{
	@stack_mem(256 + 64; Allocator mem)
	{
		DString str;
		str.init(mem, 256);
		str.appendf(fmt, ...args);
		
		if (priority >= INFO && server::is_ready) 
		{
        	log_message::send(str.str_view(), to_type(priority));
    	} 
		else 
		{
			io::eprintn(str.str_view());
		}
	};
}