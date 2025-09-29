module lsp::msg_handler::shutdown;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

struct LspShutdownRequest
{
	inline LspRequest request;
	int processId;
}
fn LspShutdownRequest? parse_message(LspMessage message)
{
	LspShutdownRequest self = {
		.request = msg_handler::get_request_struct(message)!,
	};
	if (try process_id = self.params.get_int("processId"))
	{
		self.processId = process_id;
	}
	else
	{
		log::debug("`processId` field missing");
		return msg_handler::MESSAGE_MISSING_FIELDS?;
	}
	log::info("received shutdown request");
	return self;
}

struct LspShutdownResponse
{
	String jsonrpc;
	int id;
	LspShutdownResult result;
}
alias LspShutdownResult = Maybe{void*};
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
