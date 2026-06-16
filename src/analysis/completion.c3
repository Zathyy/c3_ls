module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;

import std::collections::list;
import std::collections::map;


import uri;

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

    LspAccessKind access;
    String base_identifier; // Stores 'variable' or 'Type' string found before the operator
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
	ctx.prefix = analysis::extract_prefix(sf.source, (sz)offset);

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
    ctx.scope = analysis::find_scope(&ctx, (int)offset);

    log::info("Scope: %s", ctx.scope.description);
    log::info("base_ident: %s", ctx.base_identifier);

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

fn void provide_member_access(Context* ctx, List{CompletionItem}* items)
{
    if (ctx.access == NONE || ctx.base_identifier.len == 0) return;

    switch (ctx.access)
    {
        case STATIC:
        {
            Node* type_node = ctx.ws.find_symbol_by_name(ctx.base_identifier) ?? null;
            if (!type_node) return;
            analysis::inject_type_properties(ctx, items, type_node.kind);
            // Block general keywords/globals since we match a explicit static type path
            ctx.prefix = "\0_CONTEXT_LOCK_";
            break;
        }
        case INSTANCE:
        {
			/*
            Node* var_decl = find_local_var_declaration(ctx, ctx.base_identifier);
            if (!var_decl) return;

            StructDecl* str_decl = analysis::resolve_to_struct_decl(ctx.ws, ctx.section, var_decl);
            if (!str_decl) return;

            foreach (field_node : str_decl.fields)
            {
                VarDecl* field = field_node.as(VAR_DECL);
                Cursor cursor = { ctx.section, field_node };
                String field_name = cursor.spelling(tmem) ?? "";

                if (ctx.prefix.len == 0 || field_name.starts_with(ctx.prefix))
                {
                    items.push({
                        .label = field_name,
                        .kind = FIELD,
                        .detail = string::tformat("Field of %s", str_decl.name)
                    });
                }
            }
			*/

			HashMap{String, Node*}*? map = ctx.ws.registry.get_all_methods(ctx.base_identifier);
			if (catch map) return;
			if (!map) return;

			map.@each(; name, node)
			{
				if (ctx.prefix.len == 0 || name.starts_with(ctx.prefix))
                {
                    items.push({
                        .label = name,
                        .kind = METHOD,
                        .detail = string::tformat("method of %s", ctx.base_identifier)
                    });
                }
			};

            // Block general keywords/globals
            ctx.prefix = "\0_CONTEXT_LOCK_";
            break;
        }
        default:
    }
}

fn void provide_global(Context* ctx, List{CompletionItem}* items)
{
    String active_mod_name = ctx.section.parent_module.name;
    if (ctx.access != NONE) return;
    
    ctx.ws.modules.@each(; name, mod)
    {
        foreach (sec : mod.sections)
        {
            if (sec == ctx.section) continue;

            foreach (node : sec.nodes)
            {
				if (!node) continue;
                if (node.visibility != PUBLIC) continue;
            
                switch (node.kind)
                {
                    case MODULE_DECL: continue;
                    case IMPORT_DECL: continue;
                    default: break;
                }
                Cursor cursor = { sec, node };
                String type_name = cursor.spelling(tmem) ?? "";

                if (type_name.len == 0 || (ctx.prefix.len > 0 && !type_name.starts_with(ctx.prefix))) 
                {
                    continue;
                }
                
                items.push({
                    .label = type_name,
                    .kind = analysis::completion_kind_from_node(node),
                    // .insert_text = cursor.shortened_path(ctx.ws),
                    .detail = name,
                    .documentation = string::tformat("Type declared in module '%s'", name),
                    .sort_text = string::tformat("0002_%s", name)
                });
            }
        }
    };
} 

fn void provide_locals(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.scope != EXECUTION) return;
    if (ctx.access != NONE) return;

	Node* parent = ctx.top_level_node;
    ModuleSection* sec = ctx.section;
    if (!parent) 
    {
        log::warn("No parent");
        return;
    }
    
	if (parent.kind == FN_DECL)
    {
        FnDecl* func = parent.as(FN_DECL);
		foreach (param_node : func.params)
		{
			VarDecl* param = param_node.as(VAR_DECL);
			Cursor cursor = { sec, param_node };
			String name = cursor.spelling(tmem) ?? "";
            items.push({ 
                .label = name, 
                .kind = VARIABLE, 
                .detail = string::tformat("(parameter) %s", name),
                .sort_text = string::tformat("0001_%s", name)
            });
		}
        
		Node* body = func.body;
		switch (body.kind)
		{
			case COMPOUND_STMT:
				{
					CompoundStmt* comp = body.as(COMPOUND_STMT);
					foreach (stmt : comp.statements)
					{
						switch (stmt.kind)
						{
							case VAR_DECL:
								VarDecl* local = stmt.as(VAR_DECL);
								Cursor field_cursor = { sec, stmt };
								String name = field_cursor.spelling(tmem) ?? "";
                                if (ctx.prefix.len == 0 || name.starts_with(ctx.prefix))
                                {
                                    items.push({ 
										.label = name, 
										.kind = VARIABLE, 
										.detail = string::tformat("(local) %s", name),
										.sort_text = string::tformat("0001_%s", name)
										});
                                }
							default:
								break;
						}
					}
				}
			default: break;
		}
    }
    else if (parent.kind == MACRO_DECL)
    {
        MacroDecl* mac = parent.as(MACRO_DECL);
        foreach (param_node : mac.params)
        {
			if (param_node.kind != VAR_DECL) continue;

            VarDecl* param = param_node.as(VAR_DECL);
			Cursor cursor = { sec, param_node };
			String name = cursor.spelling(tmem) ?? "";
            items.push({ .label = name, .kind = VARIABLE, .detail = "Macro Argument" });
        }
    }
}

fn void provide_keywords(Context* ctx, List{CompletionItem}* items)
{
    if (ctx.access != NONE) return;

    foreach (kw : Keywords::values)
	{
		switch (ctx.scope)
        {
            case GLOBAL:
                if (!kw.is_top_level()) continue; 
                break;

            case CONTAINER:
                if (!kw.is_container()) continue;
                break;

            case EXECUTION:
                if (!kw.is_statement() && !kw.is_expression()) continue;
                break;
                
            case TYPE_ASSIGNMENT:
                if (!kw.is_value()) continue;
                break;
            default:
        }
        if (ctx.prefix.len == 0 || kw.name.starts_with(ctx.prefix))
        {
            items.push({
                .label = kw.name,
                .documentation = kw.docs,
                .kind = KEYWORD,
				.sort_text = string::tformat("0010_%s", kw.name),
            });
        }
	}
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
}
