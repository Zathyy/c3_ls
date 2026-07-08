module lsp::analysis::goto_definition;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;

import uri;

String string;

fn LspLocation[]? goto_definition(LspProject* project, Uri uri, LspPosition pos)
{
	log::info("goto definition");
	Location loc = { 
		.line = (sz)pos.line,
		.column = (sz)pos.character
	};

	log::info("resolve - editor location: %s:%s", loc.line + 1, loc.column + 1);
	
	List{ModuleSection*} file_sections = project.workspace.find_section_by_path(uri.path);
	if (file_sections.len() == 0)
	{
		log::info("No sections found for: %s", uri.path);
		return {};
	}
	
	SourceFile* sf = file_sections.get(0).source_file;
	sz offset = sf.line_map.get_offset(sf.source, loc);

	Cursor cursor = cursor::find_at(file_sections.get(0), (int)offset);
	if (!cursor.is_valid())
	{
		log::error("Cursor not found!");
		return {};
	}

	log::info("Kind: %s", cursor.node.kind.description);

	String symbol = extract_symbol_at_cursor(cursor, offset) ?? "";
	if (!symbol)
	{
		log::error("No valid symbol targeted at this offset context.");
		return {};
	};

	log::info("symbol: %s", symbol);

	List{LspLocation} locations; locations.tinit();
	List{SymbolEntry} entries = project.workspace.find_symbol_by_name(symbol);

	if (entries.len() <= 0)
	{
		log::error("No entries found for symbol: %s", symbol);
	}
	
	foreach (entry : entries)
	{
		ModuleSection* section = workspace::get_section_from_id(&project.workspace, (ulong)entry.section_id);
		if (!section) continue;

		SourceFile* tsf = section.source_file;

		Location start_loc = tsf.line_map.resolve((sz)entry.node.offset.start);
		Location end_loc = tsf.line_map.resolve((sz)entry.node.offset.end);

		log::debug("Adding location: %s-%s", start_loc.line, start_loc.column);

		LspLocation entry_loc = {
			.uri = (DocumentUri)string::tformat("%s", uri::from_file_path(tmem, section.source_file.file_path)),
			.range = {
				.start = {
					.line = (uint)start_loc.line,
					.character = (uint)start_loc.column
				},
				.end = {
					.line = (uint)end_loc.line,
					.character = (uint)end_loc.column
				}
			}
		};
		locations.push(entry_loc);
	}

	log::info("Sending %d", locations.len());

	return locations.array_view();
}

fn bool is_offset_in_range(sz offset, ByteOffset range) @inline
{
	int target = (int)offset;
	return target >= range.start && target <= range.end;
}

fn String? extract_symbol_at_cursor(Cursor cursor, sz offset)
{
	if (!cursor.is_valid()) return "";
	Node* node = cursor.node;

	switch (node.kind)
	{
		case FN_DECL:
		{
			FnDecl* fndecl = node.as(FnDecl);
			
			if (!is_offset_in_range(offset, fndecl.name.range)) 
			{
				log::info("Cursor inside FN_DECL but missed the name token.");
				return "";
			}
			return fndecl.name.text;
		}
		case STRUCT_DECL:
		{
			StructDecl* structdecl = node.as(StructDecl);
			
			if (!is_offset_in_range(offset, structdecl.name.range)) return "";
			
			return structdecl.name.text;
		}

		case VAR_DECL:
		{
			VarDecl* vardecl = node.as(VarDecl);
			
			if (!is_offset_in_range(offset, vardecl.name.range)) return "";
			return vardecl.name.text;
		}
		case TYPE_EXPR:
		{
			return cursor.raw_type_identifier();
		}
		default:
			return cursor.spelling(tmem);;
	}
}