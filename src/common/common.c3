module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

typedef LspUri = inline String;
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

	struct did_open
	{
		TextDocumentItem document @DField({ .rename = "textDocument" });
	}

	struct did_close
	{
		DocumentUri document @DField({ .rename = "textDocument" });
	}

	struct hover 
	{
		DocumentUri document @DField({ .rename = "textDocument/hover" });
		LspPosition position;
	}
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

$expand(derive(WorkspaceFolder::name, dessert));
struct WorkspaceFolder 
{
	LspUri uri;
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

$expand(derive(LspPosition::name, dessert));
struct LspPosition 
{
	<*
		Line position in a document (zero-based).
	*>
	uint line;
	<*
		Character offset on a line in a document (zero-based). The meaning of this
		offset is determined by the negotiated `PositionEncodingKind`.
				If the character value is greater than the line length it defaults back
		to the line length.
	*>
	uint character;
}

$expand(derive(LspRange::name, dessert));
struct LspRange 
{
	LspPosition start;
	LspPosition end;
}

$expand(derive(Location::name, dessert));
struct Location 
{
	DocumentUri uri;
	LspRange range;
}

$expand(derive(DiagnosticSeverity::name, dessert));
constdef DiagnosticSeverity : int
{
	ERROR = 1,
	WARNING = 2,
	INFORMATION = 3,
	HINT = 4,
}

$expand(derive(DiagnosticTag::name, dessert));
constdef DiagnosticTag : int 
{
	UNNECESSARY = 1,
	DEPRECATED = 2,
}

$expand(derive(Diagnostic::name, dessert));
struct Diagnostic 
{
	LspRange range;
	DiagnosticSeverity severity;
	String source;
	String message;
	DiagnosticTag[] tags;
}

$expand(derive(MarkupKind::name, dessert));
enum MarkupKind : char (String name) @DEnum({ .as = FIELD, .field = "name" })
{
	PLAIN_TEXT { "plaintext" },
	MARKDOWN   { "markdown" }
}

$expand(derive(MarkedString::name, dessert));
struct MarkedString 
{
	String language;
	String value;
}

$expand(derive(MarkupContent::name, dessert));
struct MarkupContent
{
	MarkupKind kind;
	String value;
}
