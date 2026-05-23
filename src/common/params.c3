module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

$expand(derive(MessageKind::name, dessert));
enum MessageKind : char (String name) @DEnum({ .as = FIELD, .field = "name" })
{
	UNKNOWN      { "unknown" },
	INITIALIZE   { "initialize" },
	INITIALIZED  { "initialized" },
	DID_OPEN     { "textDocument/didOpen" },
	DID_CHANGE   { "textDocument/didChange" },
	DID_CLOSE    { "textDocument/didClose" },
	DID_SAVE     { "textDocument/didSave" },
	FULL         { "textDocument/semanticTokens/full" },
	SYMBOL       { "textDocument/documentSymbol" },
	HOVER        { "textDocument/hover" },
	COMPLETION   { "textDocument/completion" },
	DEFINITION   { "textDocument/definition" },
	DECLERATION  { "textDocument/declaration" },
	REFERENCES   { "textDocument/references" },
	HELP         { "textDocument/signatureHelp" },
	RENAME       { "textDocument/rename" },
	SHUTDOWN     { "shutdown" },
	EXIT         { "exit" },
}

union MessageParams @DUnion({ .inlined = true })
{
	Object* unknown;
	InitializeParams initialize;
	DidOpenParams did_open;
	DidCloseParams did_close;
	HoverParams hover;
}

$expand(derive(InitializeParams::name, dessert));
struct InitializeParams @DStruct({ .rename_all = CAMEL_CASE })
{
	int process_id;
	struct client_info
	{
		String name;
		String version;
	}

	String locale;
	Maybe{DocumentUri} root_uri;

	Maybe{TraceKind} trace;

	WorkspaceFolder[] workspace_folders;
}

$expand(derive(DidOpenParams::name, dessert));
struct DidOpenParams
{
	TextDocumentItem document @DField({ .rename = "textDocument" });
}

$expand(derive(DidCloseParams::name, dessert));
struct DidCloseParams
{
	DocumentUri document @DField({ .rename = "textDocument" });
}

$expand(derive(HoverParams::name, dessert));
struct HoverParams
{
	DocumentUri document @DField({ .rename = "textDocument/hover" });
	LspPosition position;
}

$expand(derive(CompletionParams::name, dessert));
struct CompletionParams
{
	DocumentUri text_document;
	LspPosition position;
	CompletionContext context;
}