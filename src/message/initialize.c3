module lsp::msg_handler::initialize;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

$expand(derive(LspInitializeRequest::name, dessert));
struct LspInitializeRequest
{
	inline LspRequest request;

	int processId;
	struct client_info @DField({ .rename = "clientInfo" })
	{
		String name;
		String version;
	}
}

$expand(derive(LspInitializeParams::name, dessert));
struct LspInitializeParams @DStruct({ .rename_all = CAMEL_CASE })
{
	int process_id;
	Maybe{LspInitializeClientInfo} client_info;
}

$expand(derive(LspInitializeClientInfo::name, dessert));
struct LspInitializeClientInfo @DStruct({ .rename_all = CAMEL_CASE })
{
	int client_info;
}

fn LspInitializeRequest? parse_message(LspMessage message)
{
	LspInitializeRequest self = {
		.request = msg_handler::get_request_struct(message)!,
	};

  	log::info(ser::serialize(&&json::string_serializer(), &self)!!);

	return self;
}

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

fn String LspInitializeRequest.response(&self, Allocator allocator)
{
	LspInitializeResponse response = {
		.jsonrpc = self.jsonrpc,
		.id = self.id,
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
