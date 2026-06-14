module lsp::msg_handler::publish_diag;

import std::collections::list;

import analyzer::workspace;
import analyzer::core;
import lsp::io_handler;
import lsp::translator;
import dessert;
import derive;

import uri;

$expand(derive(MessageSeverity::name, dessert));
constdef MessageSeverity : inline int
{
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	HINT = 4,
}

$expand(derive(LspDiagnostic::name, dessert));
struct LspDiagnostic 
{
	LspRange range;
	MessageSeverity severity;
	String message;
	String source;
}

fn MessageSeverity to_severity(LogPriority prio)
{
	switch (prio)
	{
		case LogPriority.INFO:
			return MessageSeverity.INFO;
		case LogPriority.WARN:
			return MessageSeverity.WARNING;
		case LogPriority.ERROR:
		case LogPriority.CRITICAL:
			return MessageSeverity.ERROR;
		default: break;
	}

	return MessageSeverity.HINT;
}

fn void publish(Allocator allocator, ProcessResult* result)
{
	List{LspDiagnostic} diags;
	diags.tinit();

	foreach (section : result.errored_sections)
	{
		foreach (diag : section.diagnostics)
		{
			diags.push({
				.range = {
					.start = { .line = (uint)diag.start_loc.line, .character = (uint)diag.end_loc.column },
					.end = { .line = (uint)diag.start_loc.line, .character = (uint)diag.end_loc.column },
				},
				.severity = to_severity(diag.level),
				.message = diag.message,
				.source = "c3-parser"
			});
		}

		Uri file_uri = uri::from_file_path(tmem, section.source_file.file_path);
		DocumentUri formatted_uri = (DocumentUri)file_uri.to_raw_string(tmem);

		LspMessage res = {
			.rpc = "2.0",
			.method = PUB_DIAG,
			.params.pub_diag = {
				.uri = formatted_uri,
				.diagnostics = diags.to_tarray(),
			}
		};

		String response_json = translator::encode(res, allocator);

		log::debug("complete response: %s", response_json);
		io_handler::write(response_json);

		diags.clear();
	}
}
