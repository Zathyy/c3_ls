module lsp::msg_handler::text_opened;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

struct LspDidOpenTextDocumentNotification (Printable)
{
	inline LspNotification notif;
	struct params
	{
		String uri;
		String languageId;
		int version;
		String text;
	}
}
fn usz? LspDidOpenTextDocumentNotification.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);
fn LspDidOpenTextDocumentNotification? parse_message(LspMessage message)
{
	LspDidOpenTextDocumentNotification self = {
		.notif = msg_handler::get_notification_struct(message)!,
	};
	if (!self.notif.params.has_value)
	{
		log::info("params field not found (required in `textDocument/didOpen` method)");
		return msg_handler::MESSAGE_MISSING_FIELDS?;
	}
	Object* textDocument_field = self.notif.params.get().@try_get("get", "textDocument")!;
	textDocument_field.@try_get("get_string", "uri", self.params)!;
	textDocument_field.@try_get("get_string", "languageId", self.params)!;
	textDocument_field.@try_get("get_int", "version", self.params)!;
	textDocument_field.@try_get("get_string", "text", self.params)!;

	log::info("parsed didOpenTextDocument notification");
	return self;
}
