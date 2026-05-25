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
    &provide_keywords,
    &provide_global
};

fn CompletionItem[]? resolve(LspProject* project, Uri uri, LspPosition pos)
{
	log::info("resolve");
	Context ctx = (Context){
		.uri = uri,
		.position = pos,
		.ws = &project.workspace,
		.allocator = tmem,
	};

	Location loc = { 
        .line = (sz)ctx.position.line + 1, 
        .column = (sz)ctx.position.character + 1 
    };

	List{CompletionItem} items;
    items.init(tmem);

	Cursor current_cursor = ctx.ws.find_at_location(uri.path, loc);

	if (current_cursor.section != null)
    {
		ctx.section = current_cursor.section;
        SourceFile* sf = current_cursor.section.source_file;
        uint offset = sf.line_map.get_offset(sf.source, loc);
        ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset);
    }
    else
    {
        List{ModuleSection*} file_sections = ctx.ws.find_section_by_path(uri.path);
        if (file_sections.len() > 0)
        {
            ctx.section = file_sections.get(0);
        }
    }

	foreach (provider : PROVIDERS)
    {
        if (ctx.section == null && provider != &provide_keywords) continue;
        provider(&ctx, &items);
    }

	return items.array_view();
}

fn void provide_global(Context* ctx, List{CompletionItem}* items)
{
    String active_mod_name = ctx.section.parent_module.name;

    ctx.ws.modules.@each(; name, mod)
    {
        if (name != active_mod_name)
        {
            foreach (sec : mod.sections)
            {
                foreach (node_handle : sec.source_file.ast.top_level_nodes)
                {
                    if (node_handle < sec.start_node_idx || node_handle >= sec.end_node_idx) continue;

                    NodeKind kind = sec.source_file.ast.get_kind((Node)node_handle);
					switch (kind)
					{
						case MODULE_DECL: continue;
						case IMPORT_DECL: continue;
						default: break;
					}

                    Cursor cursor = { sec, (Node)node_handle };
                    String type_name = cursor.spelling() ?? "";

                    if (cursor.visibility() != PUBLIC) continue;
                    
                    if (type_name.len == 0 || (ctx.prefix.len > 0 && !type_name.starts_with(ctx.prefix))) continue;
                    
                    items.push({
                        .label = type_name.copy(ctx.allocator),
                        .kind = analysis::completion_kind_from_node(kind),
                        .insert_text = type_name,
						.detail = name,
                        .documentation = string::format(ctx.allocator, "Type declared in module '%s'", name)
                    });
                }
            }
        }
    };
}
 
fn void provide_keywords(Context* ctx, List{CompletionItem}* items)
{
    $foreach $kw : Keywords::values:
        if (ctx.prefix.len == 0 || $kw.name.starts_with(ctx.prefix))
        {
            items.push({
                .label = $kw.name,
                .documentation = $kw.docs,
                .kind = KEYWORD,
            });
        }
    $endforeach
}