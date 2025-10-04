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
	Maybe{Object*} params;
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
	Maybe{Object*} params;
}
fn usz? LspNotification.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);

enum LspAction
{
	NOTHING,
	OPEN_FILE,
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
	case "textDocument/didOpen":
		LspDidOpenTextDocumentNotification text_opened =
			text_opened::parse_message(message)!;
		log::debug("text opened: { %s, uri: \"%s\", languageId: \"%s\", version: %s }",
			text_opened.notif,
			text_opened.params.uri,
			text_opened.params.languageId,
			text_opened.params.version,
		);
		return OPEN_FILE;
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
<*
	@return "`LspNotification` struct formed from `message`"
*>
fn LspNotification? get_notification_struct(LspMessage message)
{
	return {
		.jsonrpc = message.rpc,
		.method = message.method,
		.params = maybe::value{Object*}(message.contents.get("params"))
			?? maybe::EMPTY{Object*},
	};
}
<*
	@param $get_func : "Get function to use (get_int, get_string, etc.)"
	@param $field : "Field to get and set"
	@param #variable : "Variable of which to set the field to"
		"(some_var.field = <value of $field>)"
*>
macro Object.@try_get(&self, String $get_func, String $field, #variable = EMPTY_MACRO_SLOT)
{
	$if $typeof(#variable).typeid != EmptySlot:
	if (try getted = self.$eval($get_func)($field))
	{
		#variable.$eval($field) = getted;
	}
	else
	{
		log::info("`" +++ $field +++ "` field missing");
		return MESSAGE_MISSING_FIELDS?;
	}
	$else
	if (try getted = self.$eval($get_func)($field))
	{
		return getted;
	}
	else
	{
		log::info("`" +++ $field +++ "` field missing");
		return MESSAGE_MISSING_FIELDS?;
	}
	$endif
}
