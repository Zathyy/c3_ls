module lsp::msg_handler::publish_diag;

import std::collections::list;
import std::collections::set;

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

fn void publish(Allocator allocator, FileInput[] processed_files, ProcessResult* result)
{
	HashSet{String} files_with_errors;
	files_with_errors.tinit();
	
	List{LspDiagnostic} diags;
	diags.tinit();

	foreach (section : result.errored_sections)
	{
		Uri file_uri = uri::from_file_path(tmem, section.source_file.file_path);
		DocumentUri formatted_uri = (DocumentUri)file_uri.to_raw_string(tmem);

		files_with_errors.add(section.source_file.file_path);

		foreach (diag : section.diagnostics)
		{
			diags.push({
				.range = {
					.start = { .line = (uint)diag.start_loc.line, .character = (uint)diag.start_loc.column },
					.end = { .line = (uint)diag.end_loc.line, .character = (uint)diag.end_loc.column },
				},
				.severity = to_severity(diag.level),
				.message = diag.message,
				.source = "c3-analyzer"
			});
		}

		LspMessage res = {
			.rpc = "2.0",
			.method = PUB_DIAG,
			.params.pub_diag = {
				.uri = formatted_uri,
				.diagnostics = diags.to_tarray(),
			}
		};

		String response_json = translator::encode(res, allocator);
		log::debug("Sending diagnostics for errored section: %s", response_json);
		io_handler::write(response_json);

		diags.clear();
	}

	foreach (input_file : processed_files)
	{
		String file_path = input_file.path; 
		if (file_path.len == 0) file_path = input_file.uri;

		if (files_with_errors.contains(file_path)) continue;

		Uri file_uri = uri::from_file_path(tmem, file_path);
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
		log::debug("Clearing diagnostics for clean file: %s", response_json);
		io_handler::write(response_json);
	}
}
