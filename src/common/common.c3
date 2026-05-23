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

$expand(derive(TextDocumentSyncKind::name, dessert));
constdef TextDocumentSyncKind
{
	<*
		Documents should not be synced at all.
	*>
	NONE = 0,
	<*
		Documents are synced by always sending the full content
		of the document.
	*>
	FULL = 1,
	<*
		Documents are synced by sending the full content on open.
		After that only incremental updates to the document are
		sent.
	*>
	INCREMENTAL = 2,
}

$expand(derive(TextDocumentSyncOptions::name, dessert));
struct TextDocumentSyncOptions
{
	<*
		Open and close notifications are sent to the server. If omitted open
		close notifications should not be sent.
	*>
	bool open_close @DField({ .rename = "openClose" });

	TextDocumentSyncKind change;
}

$expand(derive(CompletionTriggerKind::name, dessert));
constdef CompletionTriggerKind : int
{
	<*
	 	Completion was triggered by typing an identifier (24x7 code
	  	complete), manual invocation (e.g Ctrl+Space) or via API.
	*>
	INVOKED = 1,

	<*
	 	Completion was triggered by a trigger character specified by
		the `triggerCharacters` properties of the
		`CompletionRegistrationOptions`.
	*>
	TRIGGER_CHARACTER = 2,

	<*
		Completion was re-triggered as the current completion list is incomplete.
	*>
	TRIGGER_FOR_INCOMPLETE_COMPLETIONS = 3,
}

$expand(derive(CompletionContext::name, dessert));
struct CompletionContext
{
	CompletionTriggerKind trigger_kind;
	<*
		The trigger character (a single character) that has trigger code
	  	complete. Is undefined if
		`triggerKind !== CompletionTriggerKind.TriggerCharacter`
	*>
	Maybe{String} trigger_character;
}