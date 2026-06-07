module lsp::analysis::completion;

import parser::workspace;
import parser::ast;
import parser::cursor;

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
    
	List{CompletionItem} items; items.init(tmem);
    List{ModuleSection*} file_sections = ctx.ws.find_section_by_path(uri.path);
    if (file_sections.len() == 0)
    {
        return items.array_view(); // No tracked sections for this file yet
    }

    SourceFile* sf = file_sections.get(0).source_file;
    sz offset = sf.line_map.get_offset(sf.source, loc);
	ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset);
    
	// Cursor current_cursor = ctx.ws.find_at_location(uri.path, loc);
	//
	// if (current_cursor.section != null)
 //    {
	// 	ctx.section = current_cursor.section;
 //    }
 //    else
 //    {
	// 	ctx.section = file_sections.last()!;
 //    }  
    
	foreach (provider : PROVIDERS)
    {
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
                foreach (node : sec.nodes)
                {
					// switch (node.kind)
					// {
					// 	case MODULE_DECL: continue;
					// 	case IMPORT_DECL: continue;
					// 	default: break;
					// }
                    Cursor cursor = { sec, node };
                    String type_name = cursor.spelling(mem) ?? "";

                    if (node.visibility != PUBLIC) continue;
                    
                    if (type_name.len == 0 || (ctx.prefix.len > 0 && !type_name.starts_with(ctx.prefix))) continue;
                    
                    items.push({
                        .label = type_name.copy(ctx.allocator),
                        .kind = analysis::completion_kind_from_node(node.kind),
                        // .insert_text = cursor.shortened_path(ctx.ws),
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
