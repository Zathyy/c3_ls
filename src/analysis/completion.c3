module lsp::analysis::completion;

import c3_parser::workspace;
import c3_parser::ast;
import c3_parser::cursor;
import c3_parser::common;

import std::collections::list;

import uri;

struct Context
{
	Uri uri;
	LspPosition position;
	Workspace* ws;
	ModuleSection* section;
	Allocator allocator;
	String prefix;
}

alias CompletionProvider = fn void(Context* ctx, List{CompletionItem}* items);

const CompletionProvider[] PROVIDERS = {
    &provide_keywords
};

fn CompletionItem[]? resolve(LspProject* project, Uri uri, LspPosition pos)
{
	Context ctx = (Context){
		.uri = uri,
		.position = pos,
		.ws = &project.workspace,
		.allocator = tmem,
	};

	Location loc = { 
        .line = (sz)ctx.position.line, 
        .column = (sz)ctx.position.character 
    };

	List{CompletionItem} items;
    items.init(tmem);

	Cursor current_cursor = ctx.ws.find_at_location(uri.path, loc);

	if (current_cursor.section != null)
    {
        SourceFile* sf = current_cursor.section.source_file;
        uint offset = sf.line_map.get_offset(sf.source, loc);
        ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset);
    }

	foreach (provider : PROVIDERS)
    {
        if (ctx.section == null && provider != &provide_keywords) continue;
        provider(&ctx, &items);
    }

	return items.array_view();
}

fn void provide_keywords(Context* ctx, List{CompletionItem}* items)
{
    $foreach $kw : Keywords::values:
        if (ctx.prefix.len == 0 || $kw.name.starts_with(ctx.prefix))
        {
            items.push((CompletionItem){
                .label = $kw.name.copy(ctx.allocator),
                .documentation = $kw.docs,
                .kind = KEYWORD,
            });
        }
    $endforeach
}   