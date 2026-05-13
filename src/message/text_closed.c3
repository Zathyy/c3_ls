module lsp::msg_handler::text_closed;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

struct LspDidCloseTextDocumentNotification (Printable)
{
	inline LspNotification notif;
	struct params
	{
		String uri;
	}
}

fn usz? LspDidCloseTextDocumentNotification.to_format(&self, Formatter* f) @dynamic
{	
	io::struct_to_format(*self, f, true);
}

fn LspDidCloseTextDocumentNotification? parse_message(LspMessage message)
{
	LspDidCloseTextDocumentNotification self = {
		.notif = msg_handler::get_notification_struct(message)!,
	};

	if (!self.notif.params.has_value)
	{
		log::info("params field not found (required in `textDocument/didClose` method)");
		return msg_handler::MESSAGE_MISSING_FIELDS?;
	}

	Object* textDocument_field = self.notif.params.get().@try_get("get", "textDocument")!;
	textDocument_field.@try_get("get_string", "uri", self.params)!;

	log::info("parsed didCloseTextDocument notification");
	return self;
}
