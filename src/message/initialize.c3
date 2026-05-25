module lsp::msg_handler::initialize;
import lsp::msg_handler @norecurse;
import lsp::translator;
import lsp::io_handler;

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

fn void response(Allocator allocator, LspMessage* message)
{
	LspInitializeResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.result = {
			.capabilities = { 
				.text_document_sync = {
					.open_close = true,
					.change = FULL,
				},
				.completion_provider = {
                    .resolve_provider = true,
                    .completion_item = {
                        .label_detail_support = true
                    }
				}
			},
			.serverInfo = {
				.name = "c3_ls",
				.version = env::PROJECT_VERSION,
			},
		},
	};
	String response_json = translator::encode(response, allocator);

	log::debug("initialize response: %s", response_json);
	io_handler::write(response_json);
}
