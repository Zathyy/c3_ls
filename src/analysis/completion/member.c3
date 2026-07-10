module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

<*
 check for '.' or '::'
*>
fn void detect_access_context(Context* ctx)
{
	ctx.access = NONE;
	ctx.base_identifier = "";

	if (ctx.tokens.len() < 2) return;

	sz op_idx = -1;
	for (sz i = 0; i < ctx.tokens.len(); i++)
	{
		// If this token starts at or past the cursor, the operator must be the previous one
		if (ctx.tokens[i].pos >= ctx.offset)
		{
			op_idx = i - 1;
			break;
		}
	}
	// If the cursor is at the very end of the file, the operator is the last token
	if (op_idx == -1) op_idx = ctx.tokens.len() - 1;
	if (op_idx < 1) return; // Need at least an identifier + operator
	Token op_tok = ctx.tokens[op_idx];
	if (op_tok.kind == DOT || op_tok.kind == SCOPE)
	{
		// Ensure the token right before it is the base identifier
		Token base_tok = ctx.tokens[op_idx - 1];
		switch (base_tok.kind)
		{
			case IDENT:
			case TYPE_IDENT:
			case HASH_IDENT:
			case AT_IDENT:
				ctx.access = (op_tok.kind == SCOPE) ? LspAccessKind.STATIC : LspAccessKind.INSTANCE;
				String src = ctx.section.source_file.source;
				ctx.base_identifier = src[base_tok.pos:base_tok.len];
				ctx.base_offset = base_tok.pos;		
			default:
				break;
		}
	}
}

<*
 @returns "true if this consumed the completion (context locked to member access)"
*>
fn bool provide_member_access(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access == NONE || ctx.base_identifier.len == 0) return false;
	switch (ctx.access)
	{
		// resolve '::' with a order of
		// (ident) locals & params -> module path
		// (type_ident) TypeResolution
		case STATIC:
		{
			return provide_static_access(ctx, items);
		}
		case INSTANCE:
		{
			return provide_instance_access(ctx, items);
		}	

		default:
	}
	
	return false;
}

fn bool provide_static_access(Context* ctx, List{CompletionItem}* items)
{
	provide_module_paths(ctx, items);

	SemaScope* leaf = sema::find_deepest_scope(&ctx.section.scope, (int)ctx.offset);
	SemaVar? sema_var = leaf.find_variable(ctx.base_identifier);
	if (try sema_var && sema_var.def)
	{
		return provide_type_static_completions(ctx, items, sema_var.def);
	}

	Module* target_mod = analysis::find_module_by_identifier(ctx.ws, ctx.section.parent_module.name, ctx.base_identifier);
	if (target_mod) 
	{
		collect_module_symbols(ctx, items, target_mod);
		return true;
	}

	List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(ctx.base_identifier);
	if (try candidates) 
	{
		if (candidates.len() > 0 && candidates[0].node)
		{
			analysis::inject_type_properties(ctx, items, candidates[0].node.kind);
			return true;
		}
	}

	return false;
}

fn bool provide_instance_access(Context* ctx, List{CompletionItem}* items)
{
	List{String} chain = analysis::get_expression_chain(ctx);
	if (chain.len() == 0) return false;

	SemaScope* leaf = sema::find_deepest_scope(&ctx.section.scope, (int)ctx.offset);
	SymbolEntry result = cursor::resolve_chained_type(ctx.ws, leaf, chain.array_view());

	if (!result.node) return false;

	switch (result.node.kind)
	{
	case STRUCT_DECL:
		{
			StructDecl* str_decl = result.node.as(StructDecl);
			String type_name = str_decl.name.text;
			collect_struct_fields(ctx, items, str_decl);
			break;
		}
	//case INTERFACE_DECL:
	//	{
	//		InterfaceDecl* decl = result.node.as(InterfaceDecl);
	//		collect_methods_for_type(ctx, items, decl.name.text);
	//		break;
	//	}
	default:
	}

	//collect_methods_for_type(ctx, items, type_name);

	return true;
}

fn void collect_module_symbols(Context* ctx, List{CompletionItem}* items, Module* mod)
{
	mod.symbols.@each(; symbol_name, symbol_list)
	{
		do SYMB:
		{
			if (symbol_list.is_empty()) break SYMB;
			if (ctx.prefix.len > 0 && !symbol_name.contains(ctx.prefix)) break SYMB;

			foreach (entry : symbol_list)
			{
				if (entry.node.visibility != PUBLIC) break SYMB;
				if (entry.node.kind == MODULE_DECL || entry.node.kind == IMPORT_DECL) break SYMB;
				add_symbol_completion(ctx, items, symbol_name, entry.node, ctx.base_identifier);
			}
		};
	};
}

fn void collect_struct_fields(Context* ctx, List{CompletionItem}* items, StructDecl* str_decl)
{
	foreach (field_node : str_decl.fields)
	{
		if (field_node.kind != VAR_DECL) continue;
		VarDecl* field = field_node.as(VarDecl);
		
		String name = field.name.text;
		if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) continue;

		Cursor tc = { field.type };

		items.push({
			.label = name,
			.kind = FIELD,
			.detail = tc.spelling(tmem) ?? ""
		});
	}
}

fn void collect_methods_for_type(Context* ctx, List{CompletionItem}* items, String type_name)
{
	ctx.ws.modules.@each(; name, mod)
	{
		mod.registry.methods.@each(; MethodKey key, List{SymbolEntry} list)
		{
			do CHECK:
			{
				if (key.type_name != type_name) continue;
				if (ctx.prefix.len > 0 && !key.method_name.contains(ctx.prefix)) continue;

				foreach (en : list) {
					items.push({
						.label = key.method_name,
						.kind = METHOD,
						.detail = string::tformat("method of %s", type_name)
					});
					break;
				}
			};
		};
	};
}

fn bool provide_type_static_completions(Context* ctx, List{CompletionItem}* items, Node* var_def)
{
	Cursor type_cursor = { var_def };
	String type_spelling = type_cursor.raw_type_identifier() ?? "";
	if (type_spelling.len == 0) return false;

	List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(type_spelling);
	if (catch candidates) return false;
	if (candidates.len() == 0) return false;
	if (!candidates[0].node) return false;

	log::debug("Injecting reflection properties for instance variable type: %s", type_spelling);
	analysis::inject_type_properties(ctx, items, candidates[0].node.kind);
	return true;
}