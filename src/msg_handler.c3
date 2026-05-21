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

$expand(derive(LspActionType::name, dessert));
enum LspActionType
{
	NOTHING,
	OPEN_FILE,
	CLOSE_FILE,
	UNHANDLED_CASE,
	SHUTDOWN,
}

/// definitions at end of file
interface LspActionData
{
	fn void free();
}

struct LspAction
{
	LspActionType type;
	LspActionData data;
}

<*
	@return? MESSAGE_MISSING_FIELDS
	@return? NOT_LSP_REQUEST
*>
fn LspAction? handle_message(LspMessage message, Allocator allocator)
{
  	log::info("handling message `%s`", message.method);

	switch (message.method)
	{
	case INITIALIZE:
		LspInitializeRequest initialize = initialize::parse_message(message)!;
		log::debug("responding to `initialize` message");
		String initialize_response = initialize.response(tmem);
		io_handler::write(initialize_response);
		log::debug("responded to `initialize` message");
		return { NOTHING, LSP_ACTION_DATA_EMPTY };
    case INITIALIZED:
		return { NOTHING, LSP_ACTION_DATA_EMPTY };
    case DID_OPEN:
		LspDidOpenTextDocumentNotification text_opened =
			text_opened::parse_message(message)!;
		log::debug("text opened: { %s, uri: \"%s\", languageId: \"%s\", version: %s }",
			text_opened.notif,
			text_opened.params.uri,
			text_opened.params.languageId,
			text_opened.params.version,
			);
		return { OPEN_FILE, alloc::new(allocator, LspActionDataOpenFile,
			{
			.uri = text_opened.params.uri.copy(allocator),
			.text = text_opened.params.text.copy(allocator),
			})
		};
    case DID_CLOSE:
		LspDidCloseTextDocumentNotification text_closed =
			text_closed::parse_message(message)!;
		log::debug("text closed: { %s, uri: \"%s\", languageId: \"%s\", version: %s }",
			text_closed.notif,
			text_closed.params.uri,
			);
		return { CLOSE_FILE, alloc::new(allocator, LspActionDataCloseFile,
			{
			.uri = text_closed.params.uri.copy(allocator),
			})
		};
    case SHUTDOWN:
		LspShutdownRequest shutdown = shutdown::parse_message(message)!;
		log::debug("responding to `shutdown` message");
		String shutdown_response = shutdown.response(tmem);
		io_handler::write(shutdown_response);
		log::debug("responded to `shutdown` message");
		return { NOTHING, LSP_ACTION_DATA_EMPTY };
    case EXIT:
		return { SHUTDOWN, LSP_ACTION_DATA_EMPTY };
    default:
	}
	log::info("unhandled case");
	return { UNHANDLED_CASE, LSP_ACTION_DATA_EMPTY };
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
		.params = message.params, // maybe::value{Object*}(message.contents.get("params"))
// 			?? maybe::EMPTY{Object*},
	};
}

/// `LspActionData` definitions
// can be used for any action that doesnt have any data
struct LspActionDataEmpty (LspActionData) { char dummy; }
fn void LspActionDataEmpty.free(&self) @dynamic {}
const LspActionData LSP_ACTION_DATA_EMPTY = &&(LspActionDataEmpty){};

struct LspActionDataOpenFile (LspActionData)
{
	String uri;
	String text;
}

fn void LspActionDataOpenFile.free(&self) @dynamic
{
	mem::free(self.uri);
	mem::free(self.text);
	mem::free(self);
}

struct LspActionDataCloseFile (LspActionData)
{
	String uri;
}

fn void LspActionDataCloseFile.free(&self) @dynamic
{
	mem::free(self.uri);
	mem::free(self);
}
