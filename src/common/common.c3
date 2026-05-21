module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

typedef Uri = inline String;
typedef DocumentUri = inline String;

$expand(derive(TraceKind::name, dessert));
enum TraceKind : char (String name)
{
	OFF      { "off" },
	MESSAGES { "messages" },
	VERBOSE  { "verbose" }
}

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
			String name;
			String version;
		}

		String locale;
		DocumentUri root_uri;

		Maybe{TraceKind} trace;

		WorkspaceFolder[] workspace_folders;
	}

	struct did_open @DStruct({})
	{
		TextDocumentItem document @DField({ .rename = "textDocument" });
	}
}

$expand(derive(WorkspaceFolder::name, dessert));
struct WorkspaceFolder 
{
	Uri uri;
	String name;
}

$expand(derive(TextDocumentItem::name, dessert));
struct TextDocumentItem
{
	DocumentUri uri;
	String language_id @DField({ .rename = "languageId" });
	int version;
	String text;
}