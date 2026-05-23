module lsp::msg_handler::shutdown;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

import dessert;
import derive;

$expand(derive(LspShutdownResponse::name, dessert));
struct LspShutdownResponse
{
	String jsonrpc;
	int id;
}

fn String response(Allocator allocator, LspMessage* message) @inline
{
	LspShutdownResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
	};

	String response_json = translator::encode(response, allocator);
	log::info("Confirmed shutdown request. Awaiting exit notification...");
	return response_json;
}
