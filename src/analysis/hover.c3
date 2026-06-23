module lsp::analysis::hover;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;

import std::collections::list;
import std::collections::map;

import uri;

fn String? hover(LspProject* project, Uri uri, LspPosition pos)
{
	log::info("hover");
	Location loc = { 
        .line = (sz)pos.line,
        .column = (sz)pos.character
    };

    log::info("resolve - editor location: %s:%s", loc.line + 1, loc.column + 1);
    
    List{ModuleSection*} file_sections = project.workspace.find_section_by_path(uri.path);
    if (file_sections.len() == 0)
    {
        return "";
    }
    
	SourceFile* sf = file_sections.get(0).source_file;
	sz offset = sf.line_map.get_offset(sf.source, loc);

	Cursor cursor = cursor::find_at(file_sections.get(0), (int) offset);
	if (!cursor.is_valid()) return "";

	return cursor.spelling(tmem);
}
