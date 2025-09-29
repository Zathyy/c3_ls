module lsp::msg_handler::initialize;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::object;

struct LspInitializeRequest
{
	inline LspRequest request;
	int processId;
	struct clientInfo
	{
		String name;
		String version;
	}
}
fn LspInitializeRequest? parse_message(LspMessage message)
{
	LspInitializeRequest self;

	self.request = msg_handler::get_request_struct(message)!;
	if (try process_id = self.params.get_int("processId"))
	{
		self.processId = process_id;
	}
	else
	{
		log::debug("`processId` field missing");
		return msg_handler::MESSAGE_MISSING_FIELDS?;
	}
	if (try client_info = self.params.get("clientInfo"))
	{
		self.clientInfo.name = client_info.get_string("name")
			?? msg_handler::MESSAGE_MISSING_FIELDS?!;
		self.clientInfo.version = client_info.get_string("version")
			?? "???";
	}
	else
	{
		self.clientInfo.name = "Unknown";
		log::debug("`clientInfo` field missing");
	}
	log::info("connected to %s (%s)", self.clientInfo.name, self.clientInfo.version);

	return self;
}

struct LspInitializeResponse
{
	String jsonrpc;
	int id;
	LspInitializeResult result;
}
struct LspInitializeResult
{
	LspServerCapabilities capabilities;
	struct serverInfo
	{
		String name;
		String version;
	}
}
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
				.version = "0.1.0",
			},
		},
	};
	String response_json = translator::encode(response, allocator);

	log::debug("initialize response: %s", response_json);
	return response_json;
}
