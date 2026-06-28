module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;
import analyzer::core::lexer;

struct Context
{
	Uri uri;
	LspPosition position;
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
	ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset).trim();

	Location res_loc = sf.line_map.resolve(offset);

	log::info("resolve - parser location: %s:%s", res_loc.line + 1, res_loc.column + 1);

	ctx.access = NONE;
	ctx.base_identifier = "";

	Cursor current_cursor = ctx.ws.find_top_level_statement_at_location(uri.path, loc);
	ctx.top_level_node = current_cursor.node;
	
	if LEAF: (current_cursor.is_valid())
	{
		ctx.section = current_cursor.section;

		Cursor deep_leaf_cursor = ctx.ws.find_leaf_at_location(uri.path, loc);

		if (!deep_leaf_cursor.is_valid()) break LEAF;
		
		ctx.leaf_node = deep_leaf_cursor.node;

		log::warn("node_kind: %s", ctx.leaf_node.kind.description);

		if (current_cursor.is_access_node())
		{
			log::warn("ACCESS!!!");
			AccessExpr* access = current_cursor.node.as(ACCESS_EXPR);
			if (access.kind == STATIC)
			{
				ctx.access = LspAccessKind.STATIC;
			}
			else
			{
				ctx.access = LspAccessKind.INSTANCE;
			}
			
			if (access.left)
			{
				Cursor left_cursor = { ctx.section, access.left };
				ctx.base_identifier = left_cursor.spelling(tmem) ?? "";
				log::warn("found left on access: %s", ctx.base_identifier);
			}
		}
	}
	else
	{
		log::info("failed to find a section");
		ctx.section = file_sections.last()!;
	}
	
	context_populate_tokens(&ctx);
	ctx.scope = analysis::find_scope(&ctx, (int)offset);
	log::info("access: %s", ctx.access.description);
	log::info("Scope: %s", ctx.scope.description);
	log::info("base_ident: %s", ctx.base_identifier);
	log::info("prefix: %s", ctx.prefix);
	
	switch (ctx.scope)
	{
		case IMPORT:
			provide_imports(&ctx, &items);
			break;
		case GLOBAL:
			provide_global(&ctx, &items);
			provide_keywords(&ctx, &items);
			break;
		case CONTAINER:
			provide_locals(&ctx, &items);
			provide_global(&ctx, &items);
			provide_keywords(&ctx, &items);
			break;
		case EXECUTION:
			provide_locals(&ctx, &items);
			provide_global(&ctx, &items);
			provide_keywords(&ctx, &items);
			break;
		default:
	}

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
				.documentation = string::tformat("Import the `%s` module into this file context.", name)
			});
		};
	};

	ctx.prefix = "\0_CONTEXT_LOCK_";
}
