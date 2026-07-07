module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;
import std::collections::set;

import lsp::core;
import uri;
import analyzer::core::lexer;

struct Context
{
	Uri uri;
	LspPosition position;
	sz offset;
	sz base_offset;
	Workspace* ws;
	ModuleSection* section;
	Allocator allocator;
	String prefix;
	ScopeKind scope;
	Node* leaf_node;
	Node* top_level_node;
	<*
	 Contains all tokens of the current file
	*>
	List{Token} tokens;

	LspAccessKind access;
	String base_identifier; // Stores 'variable' or 'Type' string found before the operator
}

fn void context_populate_tokens(Context* ctx)
{
    ctx.tokens.tinit();
    
    String src = ctx.section.source_file.source;
    Lexer lexer = { .buffer = src };

    while (try t = lexer.next())
    {
        ctx.tokens.push(t);
    }
}

<*
 @param [&inout] item
*>
fn void? resolve_item(LspProject* project, CompletionItem* item)
{
	if (!item.data) return;
    String metadata = item.data;

	sz split_idx = metadata.index_of_char(';') ?? -1;
    if (split_idx < 0) return;

	String id_str = metadata[..split_idx];
    String symbol_name = metadata[split_idx + 1..];
	
	ulong section_id = id_str.to_ulong() ?? 0;

	ModuleSection* section = workspace::get_section_from_id(&project.workspace, section_id);
    if (!section) return;

	List{SymbolEntry}*? entries = project.workspace.lookup_in_module(section.parent_module.name, symbol_name);
    if (catch err = entries)
	{
		log::error("Failed to acquire symbol: %s", err);
		return;
	}
	if (entries == null) return;
	SymbolEntry entry = entries.get(0);

	switch (entry.node.kind)
	{
		case FN_DECL:
		{
			item.documentation.kind = MARKDOWN;
			Cursor cursor = { section, entry.node };
			String signature = cursor.signature_text() ?? "fn";
			FnDecl* decl = entry.node.as(FnDecl);
			if (try val = decl.contract.get())
			{
				item.documentation.value = analysis::format_contract_markdown(section, val.as(ContractDecl), signature);
			}
			else
			{
				item.documentation.value = signature;
			}
		}
		default:
	}
}

fn CompletionItem[]? resolve(LspProject* project, Uri uri, LspPosition pos)
{
	log::debug("resolve");
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
	
	log::info("resolve - editor location: %s:%s", loc.line + 1, loc.column + 1);

	List{CompletionItem} items; items.init(tmem);
	List{ModuleSection*} file_sections = ctx.ws.find_section_by_path(uri.path);
	if (file_sections.len() == 0)
	{
		return items.array_view(); // No tracked sections for this file yet
	}

	SourceFile* sf = file_sections.get(0).source_file;
	sz offset = sf.line_map.get_offset(sf.source, loc);
	ctx.offset = offset;
	ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset).trim();

	if (offset > 0 && sf.source[offset - 1] == ':')
    {
        if (offset < 2 || sf.source[offset - 2] != ':')
        {
            log::debug("Aborting completion: Triggered by a single ':' context.");
            return items.array_view(); 
        }
    }

	

	Location res_loc = sf.line_map.resolve(offset);

	log::info("resolve - parser location: %s:%s", res_loc.line + 1, res_loc.column + 1);

	ctx.access = NONE;
	ctx.base_identifier = "";

	Cursor current_cursor = ctx.ws.find_top_level_statement_at_location(uri.path, loc);
	ctx.top_level_node = current_cursor.node;
	ctx.section = current_cursor.is_valid() ? current_cursor.section : file_sections.last()!;

	context_populate_tokens(&ctx);
	detect_access_context(&ctx);
	ctx.scope = analysis::find_scope(&ctx, (int)offset);

	log::info("access: %s", ctx.access.description);
	log::info("Scope: %s", ctx.scope.description);
	log::info("base_ident: %s", ctx.base_identifier);
	log::info("prefix: %s", ctx.prefix);

	if (provide_member_access(&ctx, &items)) 
	{
		return items.array_view();
	}
	
	if (ctx.scope == IMPORT)
	{
		provide_imports(&ctx, &items);
		return items.array_view();
	}
	
	if (ctx.scope == EXECUTION || ctx.scope == CONTAINER)
	{
		provide_locals(&ctx, &items);
	}

	provide_global(&ctx, &items);
	provide_module_paths(&ctx, &items);
	provide_keywords(&ctx, &items);

	return items.array_view();
}

fn void provide_imports(Context* ctx, List{CompletionItem}* items)
{
	HashMap{String, Module*} modules = ctx.ws.modules;
	
	modules.@each(; name, mod)
	{
		do SCOPE:
		{
			if (ctx.prefix.len > 0 && !name.starts_with(ctx.prefix))
			{
				break SCOPE;
			}
			
			items.push({
				.label = name,
				.kind = MODULE,
				.detail = "Module",
				.sort_text = string::tformat("0001_%s", name),
				.documentation = { .value = string::tformat("Import the `%s` module into this file context.", name) }
			});
		};
	};

	ctx.prefix = "\0_CONTEXT_LOCK_";
}



