module lsp::msg_handler::completion;
import lsp::translator;
import lsp::io_handler;
import lsp::analysis;

import c3_parser::workspace;
import c3_parser::ast;
import c3_parser::cursor;
import c3_parser::common;

import std::io;
import std::collections::object;
import std::collections::maybe;
import std::collections::list;

import dessert;
import derive;

import uri;

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

$expand(derive(LspCompletionResponse::name, dessert));
struct LspCompletionResponse @DStruct({ .rename_all = CAMEL_CASE })
{
	String jsonrpc;
	int id;

	<*
		This list is not complete. Further typing should result in recomputing
		this list.
		Recomputed lists have all their items replaced (not appended) in the
		incomplete completion sessions.
	*>
	bool is_incomplete;

	CompletionItem[] items;
}

<*
	https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionOptions
*>
$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities @DStruct({ .rename_all = CAMEL_CASE })
{
	<*
		The additional characters, beyond the defaults provided by the client (typically
		[a-zA-Z]), that should automatically trigger a completion request. For example
		`.` in JavaScript represents the beginning of an object property or method and is
		thus a good candidate for triggering a completion request.

		Most tools trigger a completion request automatically without explicitly
		requesting it using a keyboard shortcut (e.g. Ctrl+Space). Typically they
		do so when the user starts to type an identifier. For example if the user
		types `c` in a JavaScript file code complete will automatically pop up
		present `console` besides others as a completion item. Characters that
		make up identifiers don't need to be listed here.
	*>
	String[] trigger_characters;

	<*
		The list of all possible characters that commit a completion. This field
		can be used if clients don't support individual commit characters per
		completion item. See client capability
		`completion.completionItem.commitCharactersSupport`.
	
		If a server provides both `allCommitCharacters` and commit characters on
		an individual completion item the ones on the completion item win.
	*>
	String[] all_commit_characters;

	<*
		The server provides support to resolve additional
	 	information for a completion item.
	*>
	bool resolve_provider;

	struct completion_item 
	{
		<*
			The server has support for completion item label
			details (see also `CompletionItemLabelDetails`) when receiving
			a completion item in a resolve call.
		*>
		bool label_detail_support;
	}
}

fn void response(Allocator allocator, LspProject* project, LspMessage* message)
{
	Uri? file_uri = uri::parse(tmem, message.params.completion.text_document);
	if (catch err = file_uri) return;
	LspPosition pos = message.params.completion.position;

	LspCompletionResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.is_incomplete = false,
	};

	String response_json = translator::encode(response, allocator);

	log::debug("initialize response: %s", response_json);
	io_handler::write(response_json);
}