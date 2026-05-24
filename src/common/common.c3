module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

typedef LspUri = inline String;
typedef DocumentUri = inline String;

$expand(derive(WorkspaceFolder::name, dessert));
struct WorkspaceFolder 
{
	LspUri uri;
	String name;
}

$expand(derive(TextDocumentItem::name, dessert));
struct TextDocumentItem @DStruct({ .rename_all = CAMEL_CASE })
{
	DocumentUri uri;
	String language_id;
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

$expand(derive(LspLocation::name, dessert));
struct LspLocation 
{
	DocumentUri uri;
	LspRange range;
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

$expand(derive(TextDocumentSyncOptions::name, dessert));
struct TextDocumentSyncOptions @DStruct({ .rename_all = CAMEL_CASE })
{
	<*
		Open and close notifications are sent to the server. If omitted open
		close notifications should not be sent.
	*>
	bool open_close;

	TextDocumentSyncKind change;
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

$expand(derive(CompletionItem::name, dessert));
struct CompletionItem 
{
	String label;
    CompletionItemKind kind;
    <*
        A human-readable string with additional information
	    about this item, like type or symbol information.
    *>
    String detail;
	String documentation @DField({ .skip_if_empty = true });
}