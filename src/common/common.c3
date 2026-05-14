module lsp;

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
