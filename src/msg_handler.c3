module lsp::msg_handler;
import lsp::io_handler;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

struct LspRequest
{
	String jsonrpc;
	int id;
	String method;
	Object* params;
}
fn usz? LspRequest.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);
struct LspResponse
{
	String jsonrpc;
	Maybe{int} id;
}
fn usz? LspResponse.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);
struct LspNotification
{
	String jsonrpc;
	String method;
}
fn usz? LspNotification.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);

enum LspAction
{
	NOTHING,
	YOU_FORGOT_TO_RETURN_FROM_A_CASE,
	SHUTDOWN,
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
fn LspAction? handle_message(LspMessage message)
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
		return NOTHING;
	case "initialized":
		return NOTHING;
	case "shutdown":
		LspShutdownRequest shutdown = shutdown::parse_message(message)!;
		log::debug("responding to `shutdown` message");
		String shutdown_response = shutdown.response(tmem);
		io_handler::write(shutdown_response);
		log::debug("responded to `shutdown` message");
		return NOTHING;
	case "exit":
		return SHUTDOWN;
	default:
		log::info("unknown method");
		return UNKNOWN_METHOD?;
	}
	return YOU_FORGOT_TO_RETURN_FROM_A_CASE;
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
