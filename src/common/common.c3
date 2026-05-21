module lsp;

import std::collections::object;

import dessert;
import derive;

$expand(derive(MessageKind::name, dessert));
enum MessageKind : char (String name) @DEnum({ .as = FIELD, .field = "name" })
{
	UNKNOWN      { "unknown" },
	INITIALIZE   { "initialize" },
	INITIALIZED  { "initialized" },
	DID_OPEN     { "textDocument/didOpen" },
	DID_CLOSE    { "textDocument/didClose" },
	SHUTDOWN     { "shutdown" },
	EXIT         { "exit" },
}

$expand(derive(MessageParams::name, dessert));
union MessageParams
{
	Object* unknown;
	struct initialize @DStruct({ .rename_all = CAMEL_CASE })
	{
		int process_id;
		struct client_info
		{
			String version;
		}
	}	
}
