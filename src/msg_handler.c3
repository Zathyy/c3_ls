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
	log::info("handling message `%s`", message.method);
	switch (message.method)
	{
	case "initialize":
		LspInitializeRequest initialize = initialize::parse_message(message)!;
		log::debug("responding to `initialize` message");
		String initialize_response = initialize.response(tmem);
		io_handler::write(initialize_response);
		log::debug("responded to `initialize` message");
	case "initialized":
		break;
	default:
		log::info("unknown method");
		return UNKNOWN_METHOD?;
	}
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
