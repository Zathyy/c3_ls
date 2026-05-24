module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;


$expand(derive(TraceKind::name, dessert));
enum TraceKind : char (String name)
{
	OFF      { "off" },
	MESSAGES { "messages" },
	VERBOSE  { "verbose" }
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

$expand(derive(MarkupKind::name, dessert));
enum MarkupKind : char (String name) @DEnum({ .as = FIELD, .field = "name" })
{
	PLAIN_TEXT { "plaintext" },
	MARKDOWN   { "markdown" }
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

<*
    https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
*>
$expand(derive(CompletionItemKind::name, dessert));
constdef CompletionItemKind : int
{
	TEXT = 1,
	METHOD = 2,
	FUNCTION = 3,
	CONSTRUCTOR = 4,
	FIELD = 5,
	VARIABLE = 6,
	CLASS = 7,
	INTERFACE = 8,
	MODULE = 9,
	PROPERTY = 10,
	UNIT = 11,
	VALUE = 12,
	ENUM = 13,
	KEYWORD = 14,
	SNIPPET = 15,
	COLOR = 16,
	FILE = 17,
	REFERENCE = 18,
	FOLDER = 19,
	ENUMMEMBER = 20,
	CONSTANT = 21,
	STRUCT = 22,
	EVENT = 23,
	OPERATOR = 24,
	TYPEPARAMETER = 25,
}