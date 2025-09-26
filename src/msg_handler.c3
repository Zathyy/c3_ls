module lsp::msg_handler;
import lsp::io_handler;
import lsp::translator;

import std::collections::object;

struct LspRequest
{
	String jsonrpc;
	int id;
	String method;
	Object* params;
}
struct LspResponse
{
	String jsonrpc;
	int* id;
}
struct LspNotification
{
	String jsonrpc;
	String method;
}

faultdef
	UNKNOWN_METHOD,
	MESSAGE_MISSING_FIELDS,
;
<*
	@return? UNKNOWN_METHOD
	@return? MESSAGE_MISSING_FIELDS
	@return? NOT_LSP_REQUEST
*>
fn void? handle_message(LspMessage message)
{
	switch (message.method)
	{
	default:
		return UNKNOWN_METHOD?;
	}
	log::debug("sent response");
}
faultdef NOT_LSP_REQUEST;
<*
	@return "`LspRequest` struct formed from `message`"
	@return? NOT_LSP_REQUEST: "Couldn't fetch required fields"
*>
fn LspRequest? get_request_struct(LspMessage message)
{
	return {
		.jsonrpc = message.rpc,
		.id = message.contents.get_int("id") ?? NOT_LSP_REQUEST?!,
		.method = message.method,
		.params = message.params,
	};
}
