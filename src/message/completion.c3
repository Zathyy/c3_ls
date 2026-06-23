module lsp::msg_handler::completion;
import lsp::translator;
import lsp::io_handler;
import lsp::analysis;
import lsp::core;

import std::io;
import std::collections::object;
import std::collections::maybe;
import std::collections::list;

import dessert;
import derive;

import uri;

$expand(derive(LspCompletionResponse::name, dessert));
struct LspCompletionResponse
{
	String jsonrpc;
	int id;

	struct result 
	{
		<*
			This list is not complete. Further typing should result in recomputing
			this list.
			Recomputed lists have all their items replaced (not appended) in the
			incomplete completion sessions.
		*>
		bool is_incomplete @DField({ .rename = "isIncomplete" });

		CompletionItem[] items;
	}
}

fn void response(Allocator allocator, LspProject* project, LspMessage* message)
{
	log::info("URI: %s", message.params.completion.text_document.uri);
	Uri? file_uri = uri::parse(tmem, message.params.completion.text_document.uri);
	if (catch err = file_uri)
	{
		log::error("Failed to parse uri: %s", err);
		return;
	}
	LspPosition pos = message.params.completion.position;
 
    CompletionItem[]? items = completion::resolve(project, file_uri, pos);

	LspCompletionResponse res = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.result = {
			.is_incomplete = true,
			.items = items ?? {},
		} 
	};

	String response_json = translator::encode(res, allocator);

	log::debug("complete response: %s", response_json);
	io_handler::write(response_json);
}
