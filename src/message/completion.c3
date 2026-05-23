module lsp::msg_handler::completion;
import lsp::translator;
import lsp::io_handler;

import std::io;
import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

$expand(derive(CompletionItem::name, dessert));
struct CompletionItem 
{
	String label;
	bool deprecated;
	String documentation @DField({ .skip_if_empty = true });
}

$expand(derive(LspCompletionResponse::name, dessert));
struct LspCompletionResponse
{
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
struct LspServerCapabilities
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

fn void response(Allocator allocator, LspMessage* message)
{
	LspCompletionResponse response = {
	};
	String response_json = translator::encode(response, allocator);

	log::debug("initialize response: %s", response_json);
	io_handler::write(response_json);
}
