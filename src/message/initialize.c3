module lsp::msg_handler::initialize;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

$expand(derive(LspInitializeResponse::name, dessert));
struct LspInitializeResponse
{
	String jsonrpc;
	int id;
	struct result
	{
		LspServerCapabilities capabilities;
		struct serverInfo
		{
			String name;
			String version;
		}
	}
}

$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities
{
	int textDocumentSync;
}

fn String response(Allocator allocator, LspMessage* message)
{
	LspInitializeResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.result = {
			.capabilities = { .textDocumentSync = 1 },
			.serverInfo = {
				.name = "c3_ls",
				.version = env::PROJECT_VERSION,
			},
		},
	};
	String response_json = translator::encode(response, allocator);

	log::debug("initialize response: %s", response_json);
	return response_json;
}
