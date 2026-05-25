module lsp::msg_handler::show_message;
import lsp::translator;
import lsp::io_handler;

import std::io;
import std::collections::object;
import std::collections::maybe;
import std::collections::list;

import dessert;
import derive;

import uri;

int next_id @local = 1000;

$expand(derive(MessageActionItem::name, dessert));
struct MessageActionItem
{
    String title;
}

$expand(derive(ShowMessageRequestParams::name, dessert));
struct ShowMessageRequestParams
{
    MessageType type;
    String message;
    Maybe{MessageActionItem[]} actions;
}

$expand(derive(LspShowMessageRequest::name, dessert));
struct LspShowMessageRequest
{
    String jsonrpc;
    int id;
    String method;
    ShowMessageRequestParams params;
}

fn int send_request(Allocator allocator, MessageType type, String message, String[] button_titles)
{
    int current_id = next_id++;

    MessageActionItem[] actions;
    if (button_titles.len > 0)
    {
        actions = alloc::alloc_array(allocator, MessageActionItem, button_titles.len);
        for (usz i = 0; i < button_titles.len; i++)
        {
            actions[i] = { .title = button_titles[i] };
        }
    }

    LspShowMessageRequest req = {
        .jsonrpc = "2.0",
        .id = current_id,
        .method = "window/showMessageRequest",
        .params = {
            .type = type,
            .message = message,
            .actions = maybe::value(actions),
        }
    };

    String payload = translator::encode(req, allocator);
    io_handler::write(payload);

    return current_id;
}

