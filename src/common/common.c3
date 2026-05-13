module lsp;

enum MessageKind : char (String name)
{
	UNKNOWN      { "unknown" },
	INITIALIZE   { "initialize" },
	INITIALIZED  { "initialized" },
	DID_OPEN     { "textDocument/didOpen" },
	DID_CLOSE    { "textDocument/didClose" },
	SHUTDOWN     { "shutdown" },
	EXIT         { "exit" },
}