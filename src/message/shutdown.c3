module lsp::msg_handler::shutdown;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

import dessert;
import derive;

$expand(derive(LspShutdownRequest::name, dessert));
struct LspShutdownRequest
{
	inline LspRequest request;
}

fn LspShutdownRequest? parse_message(LspMessage message)
{
	LspShutdownRequest self = {
		.request = msg_handler::get_request_struct(message)!,
	};
	log::info("received shutdown request");
	return self;
}

$expand(derive(LspShutdownResponse::name, dessert));
struct LspShutdownResponse
{
	String jsonrpc;
	int id;
	Maybe{void*} result;
}

fn String LspShutdownRequest.response(&self, Allocator allocator) @inline
{
	LspShutdownResponse response = {
		.jsonrpc = self.jsonrpc,
		.id = self.id,
		.result = {},
	};
	String response_json = translator::encode(response, allocator);
	log::debug("shutdown response: %s", response_json);
	return response_json;
}
