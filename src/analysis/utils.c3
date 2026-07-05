module lsp::analysis;

import analyzer::core;
import analyzer::cursor;

import std::collections::list;

fn String extract_prefix(String text, sz byte_offset)
{
	if (byte_offset == 0 || byte_offset > text.len) return "";

	sz start_idx = byte_offset;
	while (start_idx > 0)
	{
		char c = text[start_idx - 1];
		if (c.is_alnum() || c == '_') 
		{
			start_idx--;
		}
		else 
		{
			switch (c)
			{
				case '@':
				case '#':
				case '$':
					start_idx--;
					break;
				default: 
					break;
			}
			break;
		}
	}

	if (start_idx >= byte_offset) return "";
	return text[start_idx..byte_offset];
}

fn CompletionItemKind completion_kind_from_node(Node* node)
{
	NodeKind kind = node.kind;

	switch (kind)
	{
		case MODULE_DECL:    return MODULE;
		case FN_DECL:        return FUNCTION;
		case ENUM_DECL:      return ENUM;
		case INTERFACE_DECL: return INTERFACE;
		case STRUCT_DECL:    return STRUCT;
		case VAR_DECL:
		{
			VarDecl* var_decl = node.as(VAR_DECL);
			if (var_decl.flags.is_const)
			{
				return CONSTANT;
			}
			switch (var_decl.kind)
			{
				case VAR_FIELD:
					return FIELD;
				default:
					return VARIABLE;
			}
		}
		default:
			return TEXT;
	}
}

<*
*>
fn ScopeKind find_scope(Context* ctx, int cursor_pos)
{
	if (!ctx.top_level_node) return GLOBAL;
	Node* node = ctx.top_level_node;
	if (cursor_pos < node.offset.start || cursor_pos > node.offset.end) return GLOBAL;

	switch (node.kind)
	{
		case IMPORT_DECL: 
			return IMPORT;
		case FN_DECL:
			FnDecl* func = node.as(FN_DECL);
			if (func.body && cursor_pos >= func.body.offset.start)
			{
				return EXECUTION;
			}
			break;
		case MACRO_DECL:
			MacroDecl* mac = node.as(MACRO_DECL);
			if (mac.body  && cursor_pos >= mac.body.offset.start) 
			{
				return EXECUTION;
			}
			break;
		default:
			break;
	}

	switch (node.kind)
	{
		case STRUCT_DECL:
		{
			ScopeKind scope = NONE;
			int num_braces;
			
			foreach (t : ctx.tokens)
			{
				if (node.offset.start + t.pos >= cursor_pos) break;

				if (t.kind == LBRACE)
				{ 
					num_braces++;
					scope = CONTAINER;
				}
				if (t.kind == RBRACE)
				{ 
					num_braces--;
					if (num_braces <= 0)
					{
						scope = GLOBAL;
					}
				}
			}
			return scope;
		}

		case FN_DECL:
		case MACRO_DECL:
		{
			ScopeKind scope = GLOBAL;
			int parens;
			int braces;

			foreach (t : ctx.tokens)
			{
				if (node.offset.start + t.pos >= cursor_pos) break;

				if (t.kind == LBRACE)
				{
					braces++; 
					scope = EXECUTION;
				}
				else if (t.kind == RBRACE)
				{
					braces--; 
					scope = (braces == 0) ? GLOBAL : EXECUTION; 
				}
				else if (t.kind == LPAREN)
				{
					parens++; 
					scope = PARAMETER; 
				}
				else if (t.kind == RPAREN)
				{ 
					parens--; 
					scope = NONE; 
				}
				else if (braces == 0 && parens == 0 && t.kind == IDENT)
				{
					scope = NONE;
				}
			}
			return scope;
		}

		default:
			break;
	}

	return GLOBAL;
}

<*
*>
fn ScopeKind find_node(Context* ctx, int cursor_pos)
{
	if (!ctx.top_level_node) return GLOBAL;
	Node* node = ctx.top_level_node;
	if (cursor_pos >= node.offset.start && cursor_pos <= node.offset.end)
	{
		switch (node.kind)
		{
			case IMPORT_DECL:
				return IMPORT;
			case FN_DECL:
			case MACRO_DECL:
				return EXECUTION;
			case STRUCT_DECL:
				return CONTAINER;

			default:
				break;
		}
	}


	return GLOBAL;
}

fn MarkupContent md(String md)
{
	return {
		.value = md,
		.kind = MARKDOWN
	};
}

fn void inject_type_properties(Context* ctx, List{CompletionItem}* items, NodeKind type_kind)
{
	items.push({ .label = "alignment", .kind = PROPERTY, .detail = "sz", .documentation = md("Alignment of the type in bytes.") });
	items.push({ .label = "kind", .kind = PROPERTY, .detail = "TypeKind", .documentation = md("The underlying kind of the type") });
	items.push({ .label = "name", .kind = PROPERTY, .detail = "String", .documentation = md("The short name of the type.") });
	items.push({ .label = "qname", .kind = PROPERTY, .detail = "String", .documentation = md("The fully qualified name of the type.") });
	items.push({ .label = "size", .kind = PROPERTY, .detail = "sz", .documentation = md("Size of the type in bytes.") });
	items.push({ .label = "typeid", .kind = PROPERTY, .detail = "typeid", .documentation = md("The unique type identifier.") });
	items.push({ .label = "methods", .kind = PROPERTY, .detail = "any[]", .documentation = md("List of methods attached to this type.") });

	switch (type_kind)
	{
		case STRUCT_DECL:
			items.push({ .label = "members", .kind = PROPERTY, .detail = "any[]", .documentation = md("Array of fields/members.") });
			items.push({ .label = "get_tag", .kind = METHOD, .detail = "fn any(String)", .documentation = md("Get attributes/tags.") });
			items.push({ .label = "has_tag", .kind = METHOD, .detail = "fn bool(String)", .documentation = md("Check if attribute exists.") });
			if (type_kind == STRUCT_DECL) {
				items.push({ .label = "is_substruct", .kind = PROPERTY, .detail = "bool" });
				items.push({ .label = "parent", .kind = PROPERTY, .detail = "typeid" });
			}
			break;

		case ENUM_DECL:
			items.push({ .label = "values", .kind = PROPERTY, .detail = "any[]", .documentation = md("List of all enum variants.")});
			items.push({ .label = "len", .kind = PROPERTY, .detail = "sz", .documentation = md("Number of elements.")});
			items.push({ .label = "members", .kind = PROPERTY, .detail = "any[]" });
			items.push({ .label = "from_ordinal", .kind = METHOD, .detail = "fn type(sz)" });
			items.push({ .label = "lookup_field", .kind = METHOD, .detail = "fn any(String)" });
			break;

		case FN_DECL:
			items.push({ .label = "params", .kind = PROPERTY, .detail = "any[]", .documentation = md("Function parameter types.")});
			items.push({ .label = "returns", .kind = PROPERTY, .detail = "typeid", .documentation = md("Function return type.")});
			break;

		default:
			break;
	}
}

fn String format_contract_markdown(ModuleSection* section, ContractDecl* contract, String signature)
{
	DString md = dstring::temp_with_capacity(512);
	StringPool* pool = &section.source_file.ast.string_pool;

	md.appendf("```\n%s\n```\n", signature);
	
	String? raw_doc = contract.get_comment(pool);
	if (try raw_doc && raw_doc.len > 0)
	{
		String doc_clean = raw_doc.trim().treplace("\"", "");
		md.appendf("\n%s\n", doc_clean.trim());
	}
	
	//if (contract.params)
	//{
	//	md.append("\n#### Parameters\n");
	//	foreach (param_node : contract.params)
	//	{
	//		Cursor param_cursor = { section, param_node };
	//		String p_name = param_cursor.spelling(tmem) ?? "";
	//		String p_desc = param_cursor.source_text() ?? "";
	//		md.appendf("* **%s** : %s\n", p_name, p_desc);
	//	}
	//}
//
	//if (contract.requires)
	//{
	//	md.append("\n#### Requires (Preconditions)\n");
	//	foreach (req_expr : contract.requires)
	//	{
	//		Cursor param_cursor = { section, req_expr };
	//		String expr_str = param_cursor.source_text() ?? "";
	//		md.appendf("* `assert(%s)`\n", expr_str);
	//	}
	//}
//
	//if (contract.ensures)
	//{
	//	md.append("\n#### Ensures (Postconditions)\n");
	//	foreach (ens_expr : contract.ensures)
	//	{
	//		Cursor param_cursor = { section, ens_expr };
	//		String expr_str = param_cursor.source_text() ?? "";
	//		md.appendf("* `assert(%s)`\n", expr_str);
	//	}
	//}
//
	//if (contract.returns || contract.return_desc)
	//{
	//	md.append("\n#### Returns\n");
	//	if (contract.return_desc)
	//	{
	//		Cursor cursor = { section, contract.return_desc };
	//		String desc = cursor.source_text() ?? "";
	//		md.appendf("* Description: %s\n", desc);
	//	}
	//	foreach (ret_node : contract.returns)
	//	{
	//		Cursor param_cursor = { section, ret_node };
	//		String expr_str = param_cursor.source_text() ?? "";
	//		md.appendf("* %s\n", expr_str);
	//	}
	//}
	//
	//if (contract.deprecated)
	//{
	//	md.append("\n **Deprecated:** ");
	//	Cursor param_cursor = { section, contract.deprecated };
	//	String expr_str = param_cursor.source_text() ?? "";
	//	md.append(expr_str);
	//	md.append("\n");
	//}
		
	String raw_str = md.str_view();
	DString escape_buf = dstring::temp_with_capacity(raw_str.len * 2);
    
    // Process every single byte sequentially to avoid intermediate allocator overlap
    for (sz i = 0; i < raw_str.len; i++)
    {
        char c = raw_str[i];
        switch (c)
        {
            case '\\':
                escape_buf.append("\\\\");
                break;
            case '"':
                escape_buf.append("\\\"");
                break;
            case '\n':
                escape_buf.append("\\n");
                break;
            case '\r':
                escape_buf.append("\\r");
                break;
            case '\t':
                escape_buf.append("\\t");
                break;
            default:
                escape_buf.append_char(c);
                break;
        }
    }

    return escape_buf.str_view();
}