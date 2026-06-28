module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;


fn void provide_member_access(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access == NONE || ctx.base_identifier.len == 0) return;
	
	switch (ctx.access)
	{
		case STATIC:
		{
			List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(ctx.base_identifier);
			if (catch candidates) return;
			if (candidates.len() == 0) return;
			if (!candidates[0].node) return;
			analysis::inject_type_properties(ctx, items, candidates[0].node.kind);
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

			ctx.ws.modules.@each(; name, mod)
			{
				mod.registry.methods.@each(; MethodKey key, List{SymbolEntry} list)
				{
					if (key.type_name == ctx.base_identifier) 
					{
						if (ctx.prefix.len == 0 || key.method_name.starts_with(ctx.prefix))
						{
							foreach (entry : list) 
							{
								items.push({
									.label = key.method_name,
									.kind = METHOD,
									.detail = string::tformat("method of %s", ctx.base_identifier)
								});
								break;
							}
						}
					}
				};
			};

			
            // Block general keywords/globals
            ctx.prefix = "\0_CONTEXT_LOCK_";
            break;
        }
        default:
    }
}