module lsp::msg_handler;
import lsp::io_handler;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

import dessert;
import derive;

faultdef
	MESSAGE_MISSING_FIELDS,
	NOT_LSP_REQUEST;

$expand(derive(LspRequest::name, dessert));
struct LspRequest
{
	String jsonrpc;
	int id;
	MessageKind method;
	MessageParams params @DField({ .tagged_by = "method" });
}

$expand(derive(LspResponse::name, dessert));
struct LspResponse
{
	String jsonrpc;
	Maybe{int} id;
}

$expand(derive(LspNotification::name, dessert));
struct LspNotification
{
	String jsonrpc;
	MessageKind method;
  	MessageParams params @DField({ .tagged_by = "method" });
	// Maybe{Object*} params;
}

<*
	@return "`LspRequest` struct formed from `message`"
	@return? NOT_LSP_REQUEST: "Couldn't fetch required fields"
*>
fn LspRequest? get_request_struct(LspMessage message)
{
	return {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? NOT_LSP_REQUEST~!,
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
		.params = message.params,
	};
}